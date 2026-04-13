#!/usr/bin/env python3
"""
install.py — symlinks this repo into its expected location as the Neovim config.

Supports Linux, macOS, and Windows. Safe to re-run: already-correct links
are skipped, anything in the way is backed up with a .bak suffix.

Usage:
  python install.py          # or ./install.py on Unix
"""

import os
import platform
import shutil
import subprocess  # used for Windows junction fallback
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Config map: repo-relative source → absolute destination per platform
# Add new tools here.
# ---------------------------------------------------------------------------

def build_links(root: Path) -> list[tuple[Path, Path]]:
    system = platform.system()

    if system == "Windows":
        local_app_data = os.environ.get("LOCALAPPDATA")
        if not local_app_data:
            sys.exit("Error: %LOCALAPPDATA% is not set.")
        nvim_dst = Path(local_app_data) / "nvim"
    else:
        xdg_config = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
        nvim_dst = Path(xdg_config) / "nvim"

    return [
        (root, nvim_dst),
    ]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def find_repo_root() -> Path:
    """Return the directory containing this script (always the repo root)."""
    return Path(__file__).resolve().parent


def make_link(src: Path, dst: Path) -> None:
    src = src.resolve()

    if dst.is_symlink():
        try:
            target = dst.resolve()
        except OSError:
            target = None
        if target == src:
            print(f"  skip    {dst}")
            return
        print(f"  unlink  {dst}  (was -> {dst.readlink()})")
        dst.unlink()
    elif dst.exists():
        bak = Path(str(dst) + ".bak")
        print(f"  backup  {dst} -> {bak}")
        shutil.move(str(dst), bak)

    dst.parent.mkdir(parents=True, exist_ok=True)

    if platform.system() == "Windows":
        _windows_link(src, dst)
    else:
        os.symlink(src, dst)
        print(f"  link    {dst} -> {src}")


def _windows_link(src: Path, dst: Path) -> None:
    """Symlink on Windows, falling back to a junction for directories.

    Symlinks require Developer Mode or admin rights; directory junctions don't.
    """
    try:
        os.symlink(src, dst, target_is_directory=src.is_dir())
        print(f"  link    {dst} -> {src}")
    except OSError:
        if src.is_dir():
            result = subprocess.run(
                ["cmd", "/c", "mklink", "/J", str(dst), str(src)],
                capture_output=True, text=True,
            )
            if result.returncode != 0:
                sys.exit(f"Error creating junction: {result.stderr.strip()}")
            print(f"  junction {dst} -> {src}")
        else:
            raise


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    root = find_repo_root()
    links = build_links(root)

    print(f"Repo: {root}")
    print(f"OS:   {platform.system()}")
    print()
    print("Installing symlinks...")
    for src, dst in links:
        make_link(src, dst)
    print("\nDone.")


if __name__ == "__main__":
    main()
