# Bootstrap Fixes: setup.sh and make install

**Date:** 2026-08-06

## Overview

Found while installing miconfig on a fresh Mac. `make setup` succeeded, `make install`
printed warnings, exited clean, and installed nothing — no Neovim config, no Claude
skills, and, as it turned out, none of the command-line tools either. Eight defects
contributed, spread across `setup.sh` and `install.py`, plus one stale submodule pin.

A common theme: each failure was reported as a warning or a silent skip, so the
scripts exited successfully while leaving the machine unprovisioned.

The existing SSH-based submodule design was preserved throughout. These are
configuration bugs, not a change of approach.

## setup.sh and install.py

**1. The generated SSH key was labelled with a hardcoded email.** The address was
fixed in the script, so every key it created on any machine carried one person's
email. The email is now resolved per machine — from the local git config, or by
prompting. Cosmetic, but the label is how keys are told apart later.

**2. `~/.local/bin` was never added to PATH.** The installer places its two commands
there, then only prints a reminder that the directory should be added by hand. Each
half of the repo assumed the other handled it, so the commands installed correctly
and remained unreachable. The setup script now adds it, in a way that also reaches
machines which already ran the older version.

**3. `make install` reported success after installing nothing.** The download failure
was printed as a warning, the missing installers as harmless-looking skips, and the
script exited clean — which is what made this expensive to diagnose. It now fails
loudly and names which of the two likely causes applies.

**4. The closing "next steps" message never checked its own advice.** Registering the
generated key with GitHub is a manual step, and an unregistered key is what made
`make install` fail on the machine that prompted this write-up — the submodules are
cloned over SSH. The script printed the instruction and then declared the machine
ready regardless, so the failure surfaced several layers from its cause. The
connection is now tested, and readiness reported only when it holds.

**5. The whole package-install phase was skipped on accounts without admin rights.**
Installing Linux system packages does require those rights; installing formulae through
Homebrew, which macOS users are assumed to have already, does not. Gating both halves on the
same check left non-admin Macs with no tools whatsoever, silently. This matters most
for the `agent-*` guest accounts `guest.sh` creates, which have no sudo by design. The
macOS half now runs regardless, the Linux half still requires sudo, and any phase that
declines for lack of rights now says so instead of vanishing.

**6. Key generation aborted on machines that had never used SSH.** `ssh-keygen` does
not create `~/.ssh`, and under `set -e` the failure took the whole script down before
anything was generated. The directory is now created first. Latent rather than
observed — the machine that prompted this write-up already had `~/.ssh`.

**7. The Homebrew command used a flag that no longer exists.** `brew bundle --no-lock`
is rejected outright by current Homebrew, which removed lockfiles, so the package phase
aborted on its first command even on an admin account. The flag was dropped; it is
redundant on every supported version.

**8. The Neovim config's syntax highlighting could never work.** `nvim-treesitter`'s
current API shells out to the `tree-sitter` CLI to compile parsers. Homebrew's
`tree-sitter` formula arrives as a Neovim dependency but ships only the library, not
the CLI, and nothing installed the CLI — so every parser failed to compile and
highlighting fell back to Vim's regex engine. Added to the package list.

## nvim submodule pin

The recorded pointer referenced a commit that no longer exists upstream, so every
fresh clone broke regardless of SSH access — and left `nvim/` looking installed but
empty. Re-pinned to the current version.

This commit can be dropped if the submodule owner prefers to choose the version;
without it, however, fresh clones remain broken. The `install.py` change only makes
that failure loud and correctly diagnosed rather than silent.

## Verification

- Syntax and compile checks pass on both files.
- The email resolver was exercised on all paths, including with `git` absent.
- The PATH addition is idempotent across repeated runs, on a machine that already
  carried the older managed block.
- All four Phase 1 paths were exercised: Homebrew on PATH, Homebrew installed but off
  PATH, Homebrew absent, and Linux without sudo.
- Every claim above was re-tested rather than reasoned about. Two survived only in
  corrected form: the original installer's silent success reproduces only when *both*
  submodules are unreachable, and `~/.ssh` creation turned out to matter after being
  written off as redundant.
- `./setup.sh --phase 4` was run on a machine carrying the older managed block: the
  PATH entry was added exactly once and both commands resolve in a fresh shell.
- A clone with unpopulated submodules now exits non-zero with the new diagnostics; a
  fresh clone of the branch populates both submodules and leaves the tree clean.
- `make install` then completes, installing the Neovim config and all 42 skills.
- `./setup.sh --phase 1` was run against the fixed script and installed all 21
  Brewfile entries, each resolving in a fresh shell. `kubectl` arrives via the
  `kubernetes-cli` formula, which is expected.

Two notes on defects found in the fixes themselves, both caught by running the scripts
on a real machine rather than reading them: fix 5 reported failure even when
authentication succeeded, and an early version of the email resolver would abort on
machines without `git`. Both are fixed, and both outcomes are now tested.
