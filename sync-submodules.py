#!/usr/bin/env python3
"""
sync-submodules.py — sync a repo and its submodules to a branch.

Operates on whatever git repo the current directory belongs to, not on
miconfig specifically.

Given a branch name, checks out that branch in the parent repo and in every
submodule, fast-forwarding each to its remote. A submodule without that branch
falls back to its own default branch and says so. With no branch name, syncs
each submodule to the branch it already tracks (the original behavior).

Uncommitted changes abort the run before anything is touched. --stash opts in
to stashing them first and restoring afterwards; every stash is recorded in
.archie-sync-stashes.json at the parent repo root, with its stash SHA, so work
stays findable even if a restore conflicts.

HTTPS submodule URLs are temporarily rewritten to SSH for environments that
only have SSH keys for GitHub, then restored regardless of outcome.

Supports Linux, macOS, and Windows. Requires git in PATH.

Usage:
  python sync-submodules.py                 # track configured branches
  python sync-submodules.py qa              # parent + submodules to qa
  python sync-submodules.py qa --stash      # stash dirty trees first
  python sync-submodules.py qa --no-parent  # leave the parent repo alone
  python sync-submodules.py --json          # machine-readable summary
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

STASH_LEDGER = ".archie-sync-stashes.json"
STASH_PREFIX = "archie-sync auto-stash"


# ─── git plumbing ─────────────────────────────────────────────────────

def git(*args: str, cwd: Path, check: bool = True) -> subprocess.CompletedProcess:
    """Run a git command, capturing output."""
    result = subprocess.run(
        ["git", *args], cwd=str(cwd), capture_output=True, text=True,
    )
    if check and result.returncode != 0:
        raise GitError(f"git {' '.join(args)} (in {cwd.name}): {result.stderr.strip()}")
    return result


class GitError(RuntimeError):
    pass


def git_out(*args: str, cwd: Path) -> str:
    return git(*args, cwd=cwd).stdout.strip()


def find_repo_root() -> Path:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        )
        return Path(out.stdout.strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        sys.exit("Error: not inside a git repository (or git not found).")


def cpu_count() -> int:
    return os.cpu_count() or 4


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


# ─── reporting ────────────────────────────────────────────────────────

def line(name: str, detail: str, note: str = "") -> None:
    suffix = f"  ({note})" if note else ""
    print(f"  {name:<16} {detail}{suffix}", flush=True)


def heading(text: str) -> None:
    print(f"\n{text}", flush=True)


# ─── repo inspection ──────────────────────────────────────────────────

def submodule_paths(root: Path) -> list[str]:
    """Return submodule paths in .gitmodules order, initialized or not."""
    out = git_out(
        "config", "--file", ".gitmodules",
        "--get-regexp", r"^submodule\..*\.path$",
        cwd=root,
    )
    return [l.split(" ", 1)[1] for l in out.splitlines() if " " in l]


def dirty_files(repo: Path) -> int:
    """Count tracked-file modifications. Untracked files don't block a checkout.

    Submodule pointer moves are excluded: those are the expected product of a
    sync, not local work at risk.
    """
    out = git_out(
        "status", "--porcelain", "--untracked-files=no", "--ignore-submodules=all",
        cwd=repo,
    )
    return len([l for l in out.splitlines() if l.strip()])


def remote_has_branch(repo: Path, branch: str) -> bool:
    out = git_out("ls-remote", "--heads", "origin", branch, cwd=repo)
    return bool(out)


def default_branch(repo: Path) -> str:
    """Best effort: origin/HEAD, then the configured branch, then main."""
    result = git("symbolic-ref", "refs/remotes/origin/HEAD", cwd=repo, check=False)
    if result.returncode == 0:
        return result.stdout.strip().rsplit("/", 1)[-1]

    result = git("remote", "show", "origin", cwd=repo, check=False)
    if result.returncode == 0:
        match = re.search(r"HEAD branch:\s*(\S+)", result.stdout)
        if match and match.group(1) != "(unknown)":
            return match.group(1)

    for candidate in ("main", "master"):
        if remote_has_branch(repo, candidate):
            return candidate
    return "main"


def configured_branch(root: Path, path: str) -> str | None:
    """The branch a submodule tracks per .gitmodules, if any."""
    name = submodule_name(root, path)
    if name is None:
        return None
    result = git(
        "config", "--file", ".gitmodules", f"submodule.{name}.branch",
        cwd=root, check=False,
    )
    return result.stdout.strip() or None


def submodule_name(root: Path, path: str) -> str | None:
    out = git_out(
        "config", "--file", ".gitmodules",
        "--get-regexp", r"^submodule\..*\.path$",
        cwd=root,
    )
    for entry in out.splitlines():
        if " " not in entry:
            continue
        key, value = entry.split(" ", 1)
        if value == path:
            return key[len("submodule."):-len(".path")]
    return None


# ─── stash ledger ─────────────────────────────────────────────────────

class StashLedger:
    """Records auto-stashes at the parent repo root so they stay findable.

    Stash refs (stash@{0}) shift as the stack changes, so each entry also
    carries the stash commit SHA, which is stable and recoverable via
    `git stash apply <sha>` even after the ref moves.
    """

    def __init__(self, root: Path, branch: str | None) -> None:
        self.path = root / STASH_LEDGER
        self.branch = branch
        self.entries: list[dict] = []

    def add(self, repo_label: str, repo_path: str, abs_path: Path, sha: str,
            message: str, files: int) -> None:
        self.entries.append({
            "repo": repo_label,
            "path": repo_path,
            "abs_path": str(abs_path),
            "stash_sha": sha,
            "stash_message": message,
            "files": files,
            "status": "pending",
            "stashed_at": now(),
            "restored_at": None,
            # Absolute so it runs from any cwd, including an agent's.
            "recover_with": f"git -C {abs_path} stash apply {sha}",
        })
        self.write()

    def mark(self, repo_label: str, status: str, detail: str = "") -> None:
        for entry in self.entries:
            if entry["repo"] == repo_label:
                entry["status"] = status
                entry["restored_at"] = now()
                if detail:
                    entry["detail"] = detail
        self.write()

    def write(self) -> None:
        if not self.entries:
            if self.path.exists():
                self.path.unlink()
            return
        self.path.write_text(
            json.dumps({
                "updated": now(),
                "branch_requested": self.branch,
                "stashes": self.entries,
            }, indent=2) + "\n",
            encoding="utf-8",
        )

    @property
    def unresolved(self) -> list[dict]:
        return [e for e in self.entries if e["status"] != "restored"]


def stash_repo(repo: Path, label: str, ledger: StashLedger, repo_path: str,
               files: int, branch: str | None) -> bool:
    """Stash tracked changes. Returns True if something was stashed."""
    message = f"{STASH_PREFIX} before {branch or 'tracked-branch'} sync {now()}"
    result = git("stash", "push", "--message", message, cwd=repo, check=False)
    if result.returncode != 0:
        line(label, "stash FAILED", result.stderr.strip().splitlines()[0] if result.stderr.strip() else "unknown error")
        return False
    if "No local changes" in result.stdout:
        return False

    sha = git_out("rev-parse", "stash@{0}", cwd=repo)
    ledger.add(label, repo_path, repo, sha, message, files)
    line(label, f"stashed {files} file(s)", f"sha {sha[:9]}")
    return True


def restore_stash(repo: Path, label: str, ledger: StashLedger) -> None:
    """Re-apply a stash, or back out cleanly and leave it on the stack.

    Uses apply-then-drop rather than pop: a conflicting pop would leave
    conflict markers in a tree we just synced. On conflict the apply is
    reverted so the branch stays clean and the stash is kept intact, to be
    applied deliberately via the ledger's recover_with command.
    """
    entry = next((e for e in ledger.entries if e["repo"] == label), None)
    if entry is None:
        return

    result = git("stash", "apply", "--quiet", cwd=repo, check=False)
    if result.returncode == 0:
        git("stash", "drop", "--quiet", cwd=repo, check=False)
        ledger.mark(label, "restored")
        line(label, "stash restored")
        return

    # Back out the half-applied merge; the tree was clean before the apply.
    git("checkout", "--force", "HEAD", "--", ".", cwd=repo, check=False)
    git("reset", "--quiet", "HEAD", cwd=repo, check=False)

    ledger.mark(label, "conflict", conflict_detail(result))
    line(label, "stash kept", "conflicts with synced branch — see ledger")


def conflict_detail(result: subprocess.CompletedProcess) -> str:
    """Pull the most informative line out of a failed stash apply."""
    output = f"{result.stdout}\n{result.stderr}"
    lines = [l.strip() for l in output.splitlines() if l.strip()]
    for candidate in lines:
        if "CONFLICT" in candidate or "error:" in candidate:
            return candidate
    return lines[0] if lines else "stash apply failed"


# ─── branch sync ──────────────────────────────────────────────────────

def sync_to_branch(repo: Path, label: str, requested: str | None,
                   fallback_note: bool = True) -> dict:
    """Fetch, then move `repo` onto `requested` (or its fallback) and fast-forward.

    Returns a result record. Never force-resets: a branch that has diverged
    from its remote is reported rather than overwritten.
    """
    git("fetch", "origin", "--prune", "--quiet", cwd=repo, check=False)

    target = requested
    note = ""
    if requested is None:
        target = current_branch(repo) or default_branch(repo)
    elif not remote_has_branch(repo, requested):
        target = default_branch(repo)
        note = f"no '{requested}' branch, fell back"

    try:
        checkout(repo, target)
    except GitError as exc:
        line(label, f"→ {target}", "CHECKOUT FAILED")
        return {"repo": label, "branch": target, "status": "failed",
                "note": str(exc), "fell_back": bool(note)}

    ff = git("merge", "--ff-only", f"origin/{target}", cwd=repo, check=False)
    if ff.returncode != 0:
        line(label, f"→ {target}", "diverged from origin — not fast-forwarded")
        return {"repo": label, "branch": target, "status": "diverged",
                "note": "local commits diverge from origin; merge or rebase manually",
                "fell_back": bool(note)}

    line(label, f"→ {target}", note or "updated")
    return {"repo": label, "branch": target, "status": "ok",
            "note": note, "fell_back": bool(note)}


def current_branch(repo: Path) -> str | None:
    result = git("symbolic-ref", "--short", "-q", "HEAD", cwd=repo, check=False)
    return result.stdout.strip() or None


def checkout(repo: Path, branch: str) -> None:
    """Checkout `branch`, creating it from origin when it isn't local yet."""
    local = git("rev-parse", "--verify", "--quiet", f"refs/heads/{branch}",
                cwd=repo, check=False)
    if local.returncode == 0:
        git("checkout", "--quiet", branch, cwd=repo)
    else:
        git("checkout", "--quiet", "-b", branch, "--track", f"origin/{branch}",
            cwd=repo)


# ─── main ─────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="archie-sync",
        description="Sync the current git repo and its submodules to a branch.",
    )
    parser.add_argument(
        "branch", nargs="?",
        help="branch to sync to (default: each submodule's tracked branch)",
    )
    parser.add_argument(
        "--stash", action="store_true",
        help="stash uncommitted changes first and restore them afterwards",
    )
    parser.add_argument(
        "--no-parent", action="store_true",
        help="sync submodules only; leave the parent repo's branch alone",
    )
    parser.add_argument(
        "--json", action="store_true",
        help="print a machine-readable summary to stdout",
    )
    return parser.parse_args()


def preflight(root: Path, paths: list[str], sync_parent: bool) -> list[tuple[str, str, Path, int]]:
    """Return [(label, path, abs_path, dirty_count)] for every dirty repo."""
    dirty: list[tuple[str, str, Path, int]] = []

    if sync_parent:
        count = dirty_files(root)
        if count:
            dirty.append((root.name, ".", root, count))

    for path in paths:
        repo = root / path
        if not (repo / ".git").exists():
            continue
        count = dirty_files(repo)
        if count:
            dirty.append((path, path, repo, count))

    return dirty


def main() -> None:
    args = parse_args()
    root = find_repo_root()
    gitmodules = root / ".gitmodules"

    if not gitmodules.exists():
        sys.exit("No .gitmodules found — nothing to sync.")

    paths = submodule_paths(root)
    if not paths:
        sys.exit("No submodules configured in .gitmodules — nothing to sync.")

    sync_parent = bool(args.branch) and not args.no_parent
    ledger = StashLedger(root, args.branch)
    results: list[dict] = []
    stashed: list[tuple[str, Path]] = []

    target_desc = args.branch or "tracked branches"
    print(f"archie-sync: {root.name} → {target_desc}", flush=True)

    # ── Preflight: refuse to touch a dirty tree unless told to stash.
    dirty = preflight(root, paths, sync_parent)
    if dirty and not args.stash:
        heading("Uncommitted changes in:")
        for label, _, _, count in dirty:
            line(label, f"{count} file(s)")
        print("\nAborted — nothing was changed.", flush=True)
        print("Commit or stash your work, or re-run with --stash.", flush=True)
        sys.exit(1)

    original = gitmodules.read_text(encoding="utf-8")
    rewritten = re.sub(
        r"(url\s*=\s*)https://github\.com/", r"\1git@github.com:", original,
    )
    backup = Path(str(gitmodules) + ".bak")
    restored = False

    def restore_gitmodules() -> None:
        nonlocal restored
        if restored:
            return
        gitmodules.write_text(original, encoding="utf-8")
        git("submodule", "sync", "--quiet", cwd=root, check=False)
        restored = True

    exit_code = 0
    try:
        # ── Stash whatever the preflight flagged.
        if dirty:
            heading("Stashing uncommitted work:")
            for label, path, repo, count in dirty:
                if stash_repo(repo, label, ledger, path, count, args.branch):
                    stashed.append((label, repo))

        shutil.copy2(gitmodules, backup)
        gitmodules.write_text(rewritten, encoding="utf-8")

        # ── Parent repo.
        if sync_parent:
            heading("Parent repo:")
            results.append(sync_to_branch(root, root.name, args.branch))

        # ── Submodules: register and initialize before touching branches.
        git("submodule", "sync", "--recursive", "--quiet", cwd=root, check=False)
        init = git(
            "submodule", "update", "--init", "--recursive",
            f"--jobs={cpu_count()}", cwd=root, check=False,
        )
        if init.returncode != 0:
            heading("Warning: submodule init reported errors:")
            print(f"  {init.stderr.strip()}", flush=True)

        heading("Submodules:")
        for path in paths:
            repo = root / path
            if not (repo / ".git").exists():
                line(path, "skipped", "not initialized")
                results.append({"repo": path, "branch": None,
                                "status": "skipped", "note": "not initialized"})
                continue
            requested = args.branch or configured_branch(root, path)
            results.append(sync_to_branch(repo, path, requested))

    except GitError as exc:
        print(f"\nError: {exc}", flush=True)
        exit_code = 1
    except KeyboardInterrupt:
        print("\nInterrupted.", flush=True)
        exit_code = 130
    finally:
        # ── Restore stashes, then .gitmodules, whatever happened above.
        if stashed:
            heading("Restoring stashed work:")
            for label, repo in reversed(stashed):
                restore_stash(repo, label, ledger)

        restore_gitmodules()
        if backup.exists():
            backup.unlink()

    # ── Summary.
    ok = [r for r in results if r["status"] == "ok"]
    fell_back = [r for r in ok if r["fell_back"]]
    problems = [r for r in results if r["status"] in ("failed", "diverged")]

    heading(f"Synced {len(ok)}/{len(results)} repo(s) to '{target_desc}'.")
    if fell_back:
        print(f"  {len(fell_back)} fell back to a default branch.", flush=True)
    for r in problems:
        print(f"  {r['status']}: {r['repo']} — {r['note']}", flush=True)
        exit_code = exit_code or 1

    if ledger.unresolved:
        print(f"\n  {len(ledger.unresolved)} stash(es) NOT restored. Recorded in:",
              flush=True)
        print(f"    {ledger.path}", flush=True)
        for entry in ledger.unresolved:
            print(f"    {entry['repo']}: {entry['recover_with']}", flush=True)
        exit_code = exit_code or 1
    elif ledger.entries:
        print(f"  {len(ledger.entries)} stash(es) restored.", flush=True)

    if args.json:
        print(json.dumps({
            "root": str(root),
            "branch_requested": args.branch,
            "repos": results,
            "stashes": ledger.entries,
            "exit_code": exit_code,
        }, indent=2))

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
