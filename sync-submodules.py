#!/usr/bin/env python3
"""
sync-submodules.py — update all submodules, rewriting HTTPS URLs to SSH for
environments that only have SSH keys configured for GitHub.

Temporarily rewrites .gitmodules (HTTPS → SSH), syncs, then restores the
original content regardless of success or failure.

Supports Linux, macOS, and Windows. Requires git in PATH.

Usage:
  python sync-submodules.py
"""

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


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


def run(args: list[str], **kwargs) -> None:
    result = subprocess.run(args, **kwargs)
    if result.returncode != 0:
        sys.exit(f"Command failed: {' '.join(args)}")


def main() -> None:
    root = find_repo_root()
    gitmodules = root / ".gitmodules"

    if not gitmodules.exists():
        sys.exit("No .gitmodules found — nothing to sync.")

    original = gitmodules.read_text(encoding="utf-8")
    rewritten = re.sub(
        r"(url\s*=\s*)https://github\.com/",
        r"\1git@github.com:",
        original,
    )

    restored = False

    def restore() -> None:
        nonlocal restored
        if not restored:
            print("\nRestoring original .gitmodules...")
            gitmodules.write_text(original, encoding="utf-8")
            subprocess.run(
                ["git", "-C", str(root), "submodule", "sync", "--quiet"],
                check=False,
            )
            restored = True
            print("Restored.")

    try:
        print("Backing up .gitmodules...")
        backup = Path(str(gitmodules) + ".bak")
        shutil.copy2(gitmodules, backup)

        print("Rewriting URLs: https://github.com/ → git@github.com:...")
        gitmodules.write_text(rewritten, encoding="utf-8")

        print("Running git submodule sync...")
        run(["git", "-C", str(root), "submodule", "sync", "--recursive"])

        print(f"Updating submodules (parallel, jobs={cpu_count()})...")
        run([
            "git", "-C", str(root), "submodule", "update",
            "--init", "--recursive", "--remote", "--merge",
            f"--jobs={cpu_count()}",
        ])

        print("\nAll submodules synced successfully.")

    except SystemExit:
        restore()
        raise

    except KeyboardInterrupt:
        print("\nInterrupted.")
        restore()
        sys.exit(1)

    finally:
        restore()
        if backup.exists():
            backup.unlink()


if __name__ == "__main__":
    main()
