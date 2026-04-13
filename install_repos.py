#!/usr/bin/env python3
"""
install_repos.py — TUI installer for Blitzy-Sandbox GitHub repos.
Usage: python3 install_repos.py
"""

import argparse
import curses
import json
import os
import re
import readline
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

ORG = "Blitzy-Sandbox"


# ---------------------------------------------------------------------------
# Phase 1: Fetch
# ---------------------------------------------------------------------------

def _next_link(link_header: str) -> str | None:
    """Parse a GitHub Link header and return the 'next' page URL, or None."""
    if not link_header:
        return None
    for url, rel in re.findall(r'<([^>]+)>;\s*rel="([^"]+)"', link_header):
        if rel == "next":
            return url
    return None


def fetch_repos(org: str, token: str | None = None) -> list[dict]:
    """Return sorted list of {name, clone_url, description} for the org."""
    headers = {"User-Agent": "install-repos/1.0"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    repos = []
    url = f"https://api.github.com/orgs/{org}/repos?per_page=100&sort=name"

    while url:
        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read())
                if not isinstance(data, list):
                    msg = (data.get("message", "unexpected response format")
                           if isinstance(data, dict) else "unexpected response format")
                    print(f"GitHub API error: {msg}", file=sys.stderr)
                    sys.exit(1)
                for r in data:
                    repos.append({
                        "name": r["name"],
                        "clone_url": r["clone_url"],
                        "description": r["description"] or "",
                    })
                url = _next_link(resp.headers.get("Link", ""))
        except urllib.error.HTTPError as e:
            print(f"GitHub API error: {e.code} {e.reason}", file=sys.stderr)
            sys.exit(1)
        except Exception as e:
            print(f"Network error: {e}", file=sys.stderr)
            sys.exit(1)

    return sorted(repos, key=lambda r: r["name"].lower())


# ---------------------------------------------------------------------------
# Phase 2: Selection model
# ---------------------------------------------------------------------------

class RepoState:
    """Pure selection/filter model — no I/O."""

    def __init__(self, repos: list[dict], cloned_names: set[str]):
        self.repos = repos
        self.cloned = cloned_names
        self.selected: set[str] = set()
        self._filter = ""
        self.cursor = 0

    @property
    def filter_text(self) -> str:
        return self._filter

    @filter_text.setter
    def filter_text(self, value: str):
        self._filter = value
        n = len(self.visible)
        self.cursor = min(self.cursor, n - 1) if n > 0 else 0

    @property
    def visible(self) -> list[dict]:
        if not self._filter:
            return list(self.repos)
        q = self._filter.lower()
        return [
            r for r in self.repos
            if q in r["name"].lower() or q in r["description"].lower()
        ]

    def toggle(self, idx: int):
        if 0 <= idx < len(self.visible):
            name = self.visible[idx]["name"]
            if name in self.selected:
                self.selected.discard(name)
            else:
                self.selected.add(name)

    def toggle_all(self):
        visible_names = {r["name"] for r in self.visible}
        if visible_names.issubset(self.selected):
            self.selected -= visible_names
        else:
            self.selected |= visible_names

    def get_selected_repos(self) -> list[dict]:
        return [r for r in self.repos if r["name"] in self.selected]


# ---------------------------------------------------------------------------
# Phase 3: curses TUI
# ---------------------------------------------------------------------------

def _draw_tui(stdscr, state: RepoState, visible: list[dict],
              filtering: bool, scroll_offset: int):
    """Render one frame of the TUI."""
    h, w = stdscr.getmaxyx()
    stdscr.erase()
    n_sel = len(state.selected)
    n_total = len(state.repos)

    # Header
    header = f" {ORG} repos ({n_total}) \u2500\u2500 {n_sel} selected "
    stdscr.addstr(0, 0, header[:w].ljust(w), curses.A_REVERSE)

    # Filter bar
    cursor_char = "_" if filtering else ""
    filter_line = f" Filter: {state.filter_text}{cursor_char}"
    stdscr.addstr(1, 0, filter_line[:w].ljust(w),
                  curses.color_pair(3) if filtering else 0)

    # Separator
    stdscr.addstr(2, 0, ("\u2500" * (w - 1))[:w])

    # Repo list
    list_h = h - 5
    for i in range(list_h):
        abs_idx = i + scroll_offset
        if abs_idx >= len(visible):
            break
        repo = visible[abs_idx]
        name = repo["name"]
        desc = repo["description"]
        is_cloned = name in state.cloned
        is_selected = name in state.selected
        is_cursor = abs_idx == state.cursor

        if is_cloned:
            marker, color = "[\u2193]", curses.color_pair(2)
        elif is_selected:
            marker, color = "[x]", curses.color_pair(1)
        else:
            marker, color = "[ ]", 0

        max_desc = max(0, w - 36)
        line = f" {marker} {name:<30} {desc[:max_desc]}"
        attr = curses.A_REVERSE if is_cursor else color
        try:
            stdscr.addstr(i + 3, 0, line[:w], attr)
        except curses.error:
            pass  # writing to last cell can raise on some terminals

    # Footer
    try:
        stdscr.addstr(h - 2, 0, ("\u2500" * (w - 1))[:w])
        footer = " \u2191\u2193 navigate  Space toggle  / filter  a all/none  Enter done  q quit "
        stdscr.addstr(h - 1, 0, footer[:w], curses.A_DIM)
    except curses.error:
        pass

    stdscr.refresh()


def _tui_loop(stdscr, state: RepoState):
    curses.curs_set(0)
    curses.use_default_colors()
    curses.init_pair(1, curses.COLOR_GREEN, -1)   # selected
    curses.init_pair(2, curses.COLOR_CYAN, -1)    # already cloned
    curses.init_pair(3, curses.COLOR_YELLOW, -1)  # active filter bar

    filtering = False
    scroll_offset = 0
    prev_filter = ""

    while True:
        visible = state.visible
        h, w = stdscr.getmaxyx()
        list_h = h - 5
        if h < 6 or w < 20:
            stdscr.erase()
            msg = " Terminal too small — resize to continue "
            try:
                stdscr.addstr(0, 0, msg[:w])
            except curses.error:
                pass
            stdscr.refresh()
            stdscr.getch()
            continue

        # Reset scroll when filter changes
        if state.filter_text != prev_filter:
            scroll_offset = 0
            prev_filter = state.filter_text

        # Clamp scroll to content
        max_scroll = max(0, len(visible) - list_h)
        scroll_offset = min(scroll_offset, max_scroll)

        # Follow cursor
        if state.cursor < scroll_offset:
            scroll_offset = state.cursor
        elif len(visible) > 0 and state.cursor >= scroll_offset + list_h:
            scroll_offset = max(0, state.cursor - list_h + 1)

        _draw_tui(stdscr, state, visible, filtering, scroll_offset)
        key = stdscr.getch()

        if filtering:
            if key == 27:  # Esc — clear filter and exit filter mode
                state.filter_text = ""
                filtering = False
            elif key == 3:  # Ctrl-C — abort entirely
                return None
            elif key in (curses.KEY_BACKSPACE, 127):
                state.filter_text = state.filter_text[:-1]
            elif key == ord("\n"):
                filtering = False
            elif 32 <= key <= 126:
                state.filter_text = state.filter_text + chr(key)
        else:
            if key == curses.KEY_UP:
                state.cursor = max(0, state.cursor - 1)
            elif key == curses.KEY_DOWN:
                if len(visible) > 0:
                    state.cursor = min(len(visible) - 1, state.cursor + 1)
            elif key == ord(" "):
                state.toggle(state.cursor)
            elif key == ord("/"):
                filtering = True
            elif key == ord("a"):
                state.toggle_all()
            elif key == ord("\n"):
                return state.get_selected_repos()
            elif key in (ord("q"), 3):  # q or Ctrl-C
                return None


def run_tui(repos: list[dict], cloned: set[str]) -> list[dict] | None:
    """Launch fullscreen TUI. Returns selected repos or None if aborted."""
    state = RepoState(repos, cloned)
    return curses.wrapper(_tui_loop, state)


# ---------------------------------------------------------------------------
# Phase 4: Path prompt
# ---------------------------------------------------------------------------

def _completer(text: str, state: int):
    """Readline completer function for path completion."""
    expanded = os.path.expanduser(text)
    parent = os.path.dirname(expanded) or "."
    prefix = os.path.basename(expanded)
    try:
        entries = os.listdir(parent)
    except OSError:
        return None
    matches = []
    for entry in entries:
        if entry.startswith(prefix):
            full = os.path.join(parent, entry)
            matches.append(full + "/" if os.path.isdir(full) else full)
    try:
        return matches[state]
    except IndexError:
        return None


def prompt_destination(default: str) -> str:
    """Prompt for clone destination with readline tab-completion."""
    old_completer = readline.get_completer()
    old_delims = readline.get_completer_delims()
    readline.set_completer(_completer)
    readline.parse_and_bind("tab: complete")
    readline.set_completer_delims(" \t\n")
    try:
        path = input(f"Clone destination [{default}]: ").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        sys.exit(0)
    finally:
        readline.set_completer(old_completer)
        readline.set_completer_delims(old_delims)
    path = path or default
    path = os.path.expanduser(path)
    return os.path.abspath(path)


# ---------------------------------------------------------------------------
# Phase 5: Parallel executor
# ---------------------------------------------------------------------------

def run_jobs(repos: list[dict], dest: str, cloned: set[str], token: str | None = None) -> tuple[int, int, int, list[str]]:
    """Clone/pull repos in parallel. Returns (cloned, pulled, failed, failed_names)."""
    os.makedirs(dest, exist_ok=True)
    counts = {"cloned": 0, "pulled": 0, "failed": 0}
    failed_names: list[str] = []

    def _authed_url(url: str) -> str:
        if token and url.startswith("https://"):
            return url.replace("https://", f"https://x-access-token:{token}@", 1)
        return url

    def _job(repo: dict) -> tuple[str, str, int, str]:
        name = repo["name"]
        target = os.path.join(dest, name)
        if name in cloned and os.path.isdir(target):
            # Verify the local repo actually has commits; empty/broken repos
            # (cloned when the remote was still empty) can't be git-pulled.
            head_check = subprocess.run(
                ["git", "-C", target, "rev-parse", "--verify", "HEAD"],
                capture_output=True, timeout=10,
            )
            if head_check.returncode != 0:
                # Broken/empty local clone — remove and reclone fresh.
                shutil.rmtree(target)
            else:
                result = subprocess.run(
                    ["git", "-C", target, "pull"],
                    capture_output=True, text=True,
                    timeout=600,
                )
                action = "pulled"
                return name, action, result.returncode, result.stderr.strip()
        if not os.path.isdir(target):
            result = subprocess.run(
                ["git", "clone", _authed_url(repo["clone_url"]), target],
                capture_output=True, text=True,
                timeout=600,
            )
            action = "cloned"
        return name, action, result.returncode, result.stderr.strip()

    workers = min(8, max(1, len(repos)))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(_job, r): r for r in repos}
        try:
            for fut in as_completed(futures):
                try:
                    name, action, code, err = fut.result()
                except Exception as exc:
                    repo = futures[fut]
                    print(f"  \u2717 failed  {repo['name']}  ({exc})")
                    counts["failed"] += 1
                    failed_names.append(repo["name"])
                    continue
                if code == 0:
                    print(f"  \u2713 {action:<7} {name}")
                    counts[action] += 1
                else:
                    short_err = (err.splitlines()[-1][:80] if err else "unknown error")
                    print(f"  \u2717 failed  {name}  ({short_err})")
                    counts["failed"] += 1
                    failed_names.append(name)
        except KeyboardInterrupt:
            print("\nInterrupted — cancelling queued jobs…", flush=True)
            for f in futures:
                f.cancel()
            raise

    return counts["cloned"], counts["pulled"], counts["failed"], failed_names


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    if sys.version_info < (3, 10):
        sys.exit("install_repos.py requires Python 3.10 or later")
    try:
        _main()
    except KeyboardInterrupt:
        print("\nAborted.", flush=True)
        sys.exit(130)


def _main() -> None:
    parser = argparse.ArgumentParser(description=f"TUI installer for GitHub org repos")
    parser.add_argument("--org", "-o", default=ORG, metavar="ORG",
                        help=f"GitHub organisation to fetch repos from (default: {ORG})")
    parser.add_argument("--repos", "-r", nargs="+", metavar="NAME",
                        help="repo names to clone/pull directly, skipping the TUI")
    args = parser.parse_args()
    org = args.org

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN") or None

    print(f"Fetching repos from {org}...")
    repos = fetch_repos(org, token)
    print(f"Found {len(repos)} repos.")

    cwd = os.getcwd()

    if args.repos:
        # Direct mode: named repos, no TUI
        repo_map = {r["name"]: r for r in repos}
        unknown = [n for n in args.repos if n not in repo_map]
        if unknown:
            print(f"Warning: unknown repos: {', '.join(unknown)}", file=sys.stderr)
        selected = [repo_map[n] for n in args.repos if n in repo_map]
        if not selected:
            sys.exit("No valid repos specified.")
    else:
        # Interactive mode: curses TUI
        cloned_in_cwd = {
            r["name"] for r in repos
            if os.path.isdir(os.path.join(cwd, r["name"], ".git"))
        }
        selected = run_tui(repos, cloned_in_cwd)
        if selected is None:
            print("Aborted.")
            sys.exit(0)
        if not selected:
            print("Nothing selected.")
            sys.exit(0)

    dest = prompt_destination(cwd)

    # Re-check cloned status against the final chosen destination
    cloned_in_dest = {
        r["name"] for r in selected
        if os.path.isdir(os.path.join(dest, r["name"], ".git"))
    }

    print(f"\nTarget:  {dest}")
    print(f"Queued:  {len(selected)} repo(s)\n")

    n_cloned, n_pulled, n_failed, failed_names = run_jobs(selected, dest, cloned_in_dest, token)
    print(f"\nDone: {n_cloned} cloned, {n_pulled} pulled, {n_failed} failed")

    if n_failed:
        script = os.path.basename(sys.argv[0])
        org_flag = f"--org {org} " if org != ORG else ""
        retry = f"python3 {script} {org_flag}--repos " + " ".join(failed_names)
        print(f"\nRetry failed:\n  {retry}")

    sys.exit(1 if n_failed else 0)


if __name__ == "__main__":
    main()
