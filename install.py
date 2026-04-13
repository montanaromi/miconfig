#!/usr/bin/env python3
"""
install.py — installs all configs managed by miconfig.

Runs each submodule's own installer in sequence, then installs CLI commands
into the user's PATH. Safe to re-run.

Usage:
  python install.py          # or ./install.py on Unix
  make install
"""

import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# Commands to expose globally: bin/<name> → <user-bin>/<name>
COMMANDS = [
    "archie-sync",
]


def run(installer: Path) -> bool:
    """Run an installer script and return True on success."""
    rel = installer.relative_to(HERE)
    print(f"\n=== {rel} ===", flush=True)
    result = subprocess.run([sys.executable, str(installer)])
    if result.returncode != 0:
        print(f"  warning: {rel} exited with code {result.returncode}", flush=True)
        return False
    return True


def user_bin_dir() -> Path:
    """Return a user-writable bin directory that is (or should be) on PATH."""
    if platform.system() == "Windows":
        base = os.environ.get("LOCALAPPDATA") or str(Path.home())
        return Path(base) / "Programs" / "miconfig" / "bin"
    return Path.home() / ".local" / "bin"


def install_commands() -> None:
    print("\n=== bin/ commands ===", flush=True)
    bin_dir = user_bin_dir()
    bin_dir.mkdir(parents=True, exist_ok=True)

    for name in COMMANDS:
        src = (HERE / "bin" / name).resolve()
        dst = bin_dir / name

        if not src.exists():
            print(f"  skip    {name} (not found in bin/)")
            continue

        if dst.is_symlink():
            if dst.resolve() == src:
                print(f"  skip    {dst} (already linked)")
                continue
            dst.unlink()
        elif dst.exists():
            bak = Path(str(dst) + ".bak")
            print(f"  backup  {dst} -> {bak}")
            shutil.move(str(dst), bak)

        if platform.system() == "Windows":
            _windows_command(src, dst, bin_dir, name)
        else:
            os.symlink(src, dst)
            print(f"  link    {dst} -> {src}")

    if platform.system() != "Windows" and str(bin_dir) not in os.environ.get("PATH", ""):
        print(f"\n  note: add {bin_dir} to your PATH if not already present")


def _windows_command(src: Path, dst: Path, bin_dir: Path, name: str) -> None:
    """On Windows, create a .bat shim alongside the symlink/copy."""
    bat = bin_dir / f"{name}.bat"
    bat.write_text(
        f'@echo off\npython "{src}" %*\n',
        encoding="utf-8",
    )
    print(f"  shim    {bat} -> {src}")
    print(f"  note: add {bin_dir} to your PATH")


def main() -> None:
    installers = [
        HERE / "nvim" / "install.py",
        HERE / "claude-config" / "install.py",
    ]

    failed = []
    for installer in installers:
        if not installer.exists():
            print(f"  skip  {installer.relative_to(HERE)} (not found)", flush=True)
            continue
        if not run(installer):
            failed.append(installer.relative_to(HERE))

    install_commands()

    print()
    if failed:
        print("Completed with errors:")
        for f in failed:
            print(f"  - {f}")
        sys.exit(1)
    else:
        print("All installers complete.")


if __name__ == "__main__":
    main()
