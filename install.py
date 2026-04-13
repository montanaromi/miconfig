#!/usr/bin/env python3
"""
install.py — installs all configs managed by miconfig.

Runs each submodule's own installer in sequence. Safe to re-run.

Usage:
  python install.py          # or ./install.py on Unix
  make install
"""

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def run(installer: Path) -> bool:
    """Run an installer script and return True on success."""
    rel = installer.relative_to(HERE)
    print(f"\n=== {rel} ===", flush=True)

    result = subprocess.run([sys.executable, str(installer)])
    if result.returncode != 0:
        print(f"  warning: {rel} exited with code {result.returncode}", flush=True)
        return False
    return True


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
