<!-- Shields bar -->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]

<!-- Project header -->
<div align="center">
  <h1>miconfig</h1>
  <p>Dev environment provisioning and config management. One repo, one command, any machine.</p>
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
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>

---

## About The Project

miconfig is a single repo that provisions a dev machine from scratch and keeps configs in sync across machines. It handles everything from system packages to shell configuration, and works on both macOS and Ubuntu.

The provisioner runs in 6 idempotent phases. Each phase detects what's already installed and skips it, so the script is safe to re-run at any time. Guest accounts get the same dev tools with limited sudo, keeping shared machines clean.

Config management is handled through git submodules (neovim, Claude Code) and a symlink installer that places configs in their OS-specific locations.

## Built With

[![Python][python-shield]][python-url]
[![Bash][bash-shield]][bash-url]
[![JavaScript][javascript-shield]][javascript-url]

## Getting Started

### Prerequisites

- Git
- macOS or Ubuntu/Debian
- Internet connection (for package downloads)

### Installation

**Fresh machine:**

```bash
git clone https://github.com/montanaromi/miconfig.git ~/Lab/Utils/miconfig
cd ~/Lab/Utils/miconfig
make setup
```

**Existing machine (configs only):**

```bash
git clone https://github.com/montanaromi/miconfig.git ~/Lab/Utils/miconfig
cd ~/Lab/Utils/miconfig
make install
```

## Usage

### `make setup`

Provisions a dev machine in 6 phases. Detects macOS vs Linux and installs accordingly.

| Phase | What | macOS | Ubuntu |
|-------|------|-------|--------|
| 1 | System packages | Homebrew | apt |
| 2 | Docker, gcloud, az, gh, kubectl, helm, k3d, 1Password, .NET | manual / cask | apt repos |
| 3 | Go, pyenv (3.12 + 3.13), nvm (LTS), Rust | same | same |
| 4 | zsh, Oh My Zsh, SSH key, .zshrc integrations | same | same |
| 5 | `~/Lab/{Work,Sandbox,Utils}`, `~/notes/`, journal system | same | same |
| 6 | Firefox, Spotify, Slack, PyCharm, Postman | App Store | snap |

Run a single phase:

```bash
./setup.sh --phase 3
```

Guest accounts (limited sudo) automatically skip phases 1, 2, and 6.

### `make guest`

Creates a guest dev account named `agent-<name>` with limited sudo (apt/snap only) and runs setup as that user.

```bash
make guest            # prompts for name + password
make guest NAME=fde   # skip prompt, creates agent-fde
```

### `make install`

Symlinks neovim and Claude Code configs into their OS-specific locations, sets up git aliases, and runs each submodule's installer.

### `make sync`

Updates all git submodules. Temporarily rewrites HTTPS URLs to SSH for environments with only SSH auth, then restores the originals.

## Structure

```
miconfig/
  setup.sh              cross-platform machine provisioner (phases 1-6)
  guest.sh              guest account creator (agent-<name>)
  install.py            config symlinker + git alias setup
  install_repos.py      TUI for cloning Blitzy-Sandbox org repos
  sync-submodules.py    submodule updater (HTTPS-to-SSH rewrite)
  Makefile              entry points: setup, guest, install, sync
  bin/
    archie-sync         run sync-submodules.py from anywhere via symlink
  nvim/                 neovim config (submodule: mivim)
  claude-config/        Claude Code config (submodule)
  nvimcollab/           real-time neovim collaboration prototype
    nvim-plugin/        neovim sidecar client (Yjs + WebSocket)
    server/             WebSocket relay server
    web/                browser-based collaborative editor (CodeMirror + Yjs)
  docs/
    superpowers/        Claude Code skill documentation
```

### Submodules

| Path | Repo | Purpose |
|------|------|---------|
| `nvim/` | [mivim](https://github.com/montanaromi/mivim) | Neovim configuration |
| `claude-config/` | [claude-config](https://github.com/montanaromi/claude-config) | Claude Code settings |

### Shell Config

`setup.sh` installs into `~/.zshrc` and `~/.shell-config.d/`:

- **Oh My Zsh** with `xiong-chiamiov-plus` theme
- **pyenv**, **nvm**, **cargo** PATH integrations
- **Journal system** with `journal`, `note`, `todo`, `todos` commands
- Aliases: `vim` to nvim, `blitz` to `~/Lab/Work`, `sandbox` to `~/Lab/Sandbox`

## Contributing

Contributions make the open source community an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/amazing-feature`)
3. Commit your Changes (`git commit -m 'Add amazing feature'`)
4. Push to the Branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

Michael Montanaro

Project Link: [https://github.com/montanaromi/miconfig](https://github.com/montanaromi/miconfig)

## Acknowledgments

- [Oh My Zsh](https://ohmyz.sh/)
- [pyenv](https://github.com/pyenv/pyenv)
- [nvm](https://github.com/nvm-sh/nvm)
- [Neovim](https://neovim.io/)

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
[license-shield]: https://img.shields.io/github/license/montanaromi/miconfig.svg?style=flat
[license-url]: https://github.com/montanaromi/miconfig/blob/main/LICENSE
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-blue.svg?style=flat&logo=linkedin
[linkedin-url]: https://linkedin.com/in/michael-montanaro
[python-shield]: https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white
[python-url]: https://python.org
[bash-shield]: https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white
[bash-url]: https://www.gnu.org/software/bash/
[javascript-shield]: https://img.shields.io/badge/JavaScript-F7DF1E?style=flat&logo=javascript&logoColor=black
[javascript-url]: https://developer.mozilla.org/en-US/docs/Web/JavaScript
