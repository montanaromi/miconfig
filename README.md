<!-- Shields bar -->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]

<!-- Project header -->
<div align="center">
  <h1>miconfig</h1>
  <p>Cross-platform developer tooling monorepo — dotfiles, Claude Code skills, and Neovim config, all wired together by a single <code>make install</code>.</p>
  <a href="https://github.com/montanaromi/miconfig"><strong>Explore the docs</strong></a>
  &middot;
  <a href="https://github.com/montanaromi/miconfig/issues/new?labels=bug">Report Bug</a>
  &middot;
  <a href="https://github.com/montanaromi/miconfig/issues/new?labels=enhancement">Request Feature</a>
</div>

<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#about-the-project">About The Project</a></li>
    <li><a href="#built-with">Built With</a></li>
    <li><a href="#getting-started">Getting Started</a></li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#structure">Structure</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>

---

## About The Project

**miconfig** is a personal developer configuration monorepo that manages dotfiles, [Claude Code](https://claude.ai/code) skills, and Neovim configuration across machines. It is not an application — it is a toolbox of cross-platform install scripts and skill backends that wire everything into place.

The root repo ties together two git submodules:

- **`claude-config/`** — Claude Code skills with Python backends (tree-sitter parsers, log analyzers, document validators) that extend Claude Code's capabilities
- **`nvim/`** — Neovim configuration (Lua-based, lazy.nvim plugin manager)

A single `make install` symlinks all configs into their OS-specific locations and installs Python dependencies. A companion `make sync` keeps submodules up to date, transparently translating HTTPS URLs to SSH for environments that authenticate via SSH keys.

## Built With

[![Python][python-shield]][python-url]
[![Neovim][neovim-shield]][neovim-url]
[![tree-sitter][treesitter-shield]][treesitter-url]

## Getting Started

### Prerequisites

- Python 3.x (stdlib only — no third-party packages required for the install scripts)
- Git (with SSH keys configured for GitHub)
- Neovim 0.10+ (for the nvim submodule)
- `tree-sitter` Python package (auto-installed by `claude-config/install.py` for skill backends)

### Installation

```bash
# Clone with submodules
git clone --recurse-submodules git@github.com:montanaromi/miconfig.git
cd miconfig

# Symlink all configs into place (cross-platform)
make install

# Keep submodules in sync (handles SSH/HTTPS URL translation)
make sync
```

**What `make install` does:**

1. Runs `install.py` — symlinks scripts in `bin/` to `~/.local/bin` (Linux/Mac) or `%APPDATA%` (Windows)
2. Runs `claude-config/install.py` — symlinks skills into `~/.claude/skills/` and installs pip deps
3. Runs `nvim/install.py` — symlinks Neovim config into `~/.config/nvim/`

## Usage

### Bulk GitHub Repo Installer

Interactive TUI for cloning multiple repos from a GitHub user or org:

```bash
python install_repos.py --user <github-username>
python install_repos.py --org <github-org>
```

Navigate with arrow keys, toggle selection with Space, confirm with Enter. Clones run in parallel.

### Submodule Sync

```bash
make sync
```

Rewrites `.gitmodules` HTTPS URLs to SSH, updates all submodules, then restores the original `.gitmodules`. Safe to re-run at any time.

### Claude Code Skills

Skills are symlinked into `~/.claude/skills/` and immediately available in Claude Code. Edits to skill files in this repo take effect without reinstalling.

Available skills include: `onboard`, `aap`, `tech-spec`, `logger`, and others in `claude-config/skills/`.

## Structure

```
miconfig/
├── Makefile                  # install + sync targets
├── install.py                # Root cross-platform installer
├── install_repos.py          # Interactive TUI for bulk GitHub repo cloning
├── sync-submodules.py        # Git submodule sync with HTTPS→SSH translation
├── requirements.txt          # Placeholder (stdlib only)
├── bin/                      # Scripts installed to user PATH
├── docs/                     # Design specs and implementation plans
├── claude-config/            # Submodule: Claude Code skills
│   ├── install.py            # Skills installer + pip deps
│   └── skills/
│       ├── onboard/          # Codebase structural mapper (tree-sitter)
│       ├── aap/              # Agent Action Plan document parser
│       ├── tech-spec/        # Technical Specification parser
│       └── logger/           # GCP kubectl log gap analysis
├── nvim/                     # Submodule: Neovim configuration
│   ├── init.lua              # Entry point (lazy.nvim)
│   └── lua/                  # Plugin configs and LSP setup
└── openvino-npu/             # Intel NPU inference experiments
```

## Contact

Michael Montanaro — michael@blitzy.com

Project Link: [https://github.com/montanaromi/miconfig](https://github.com/montanaromi/miconfig)

## Acknowledgments

- [Claude Code](https://claude.ai/code) — AI coding assistant whose skill system this repo extends
- [tree-sitter](https://tree-sitter.github.io/tree-sitter/) — Parser library powering the skill backends
- [lazy.nvim](https://github.com/folke/lazy.nvim) — Neovim plugin manager

---

<!-- Reference-style links -->
[contributors-shield]: https://img.shields.io/github/contributors/montanaromi/miconfig.svg?style=flat
[contributors-url]: https://github.com/montanaromi/miconfig/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/montanaromi/miconfig.svg?style=flat
[forks-url]: https://github.com/montanaromi/miconfig/network/members
[stars-shield]: https://img.shields.io/github/stars/montanaromi/miconfig.svg?style=flat
[stars-url]: https://github.com/montanaromi/miconfig/stargazers
[issues-shield]: https://img.shields.io/github/issues/montanaromi/miconfig.svg?style=flat
[issues-url]: https://github.com/montanaromi/miconfig/issues
[python-shield]: https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white
[python-url]: https://python.org
[neovim-shield]: https://img.shields.io/badge/Neovim-57A143?style=flat&logo=neovim&logoColor=white
[neovim-url]: https://neovim.io
[treesitter-shield]: https://img.shields.io/badge/tree--sitter-2088FF?style=flat&logo=github&logoColor=white
[treesitter-url]: https://tree-sitter.github.io/tree-sitter/
