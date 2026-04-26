# miconfig

Dev environment provisioning and config management. One repo, one command, any machine.

## Quick Start

**Fresh machine (macOS or Ubuntu):**

```bash
git clone https://github.com/montanaromi/miconfig.git ~/Lab/Utils/miconfig
cd ~/Lab/Utils/miconfig
make setup
```

**Existing machine (just configs):**

```bash
make install
```

## What It Does

### `make setup`

Provisions a dev machine in 6 phases. Idempotent — safe to re-run. Detects macOS vs Linux and installs accordingly.

| Phase | What | macOS | Ubuntu |
|-------|------|-------|--------|
| 1 | System packages | Homebrew | apt |
| 2 | Docker, gcloud, az, gh, kubectl, helm, k3d, 1Password, .NET | brew cask (manual) | apt repos + install |
| 3 | Go, pyenv (3.12 + 3.13), nvm (LTS), Rust | same | same |
| 4 | zsh, Oh My Zsh, SSH key, .zshrc integrations | same | same |
| 5 | `~/Lab/{Work,Sandbox,Utils}`, `~/notes/`, journal system | same | same |
| 6 | Firefox, Spotify, Slack, PyCharm, Postman | App Store / cask | snap |

Run a single phase: `./setup.sh --phase 3`

Guest accounts (limited sudo) skip phases 1, 2, and 6 automatically.

### `make guest`

Creates a guest dev account named `agent-<name>` with limited sudo (apt/snap only) and runs `make setup` as that user.

```bash
make guest            # prompts for name + password
make guest NAME=fde   # skip name prompt → creates agent-fde
```

### `make install`

Symlinks configs (neovim, Claude Code) into their OS-specific locations and sets up git aliases. Runs each submodule's own installer.

### `make sync`

Updates all git submodules. Temporarily rewrites HTTPS URLs to SSH for environments with only SSH auth, then restores the originals.

## Structure

```
miconfig/
  setup.sh            # machine provisioner (phases 1-6)
  guest.sh            # guest account creator
  install.py          # config symlinker + git setup
  install_repos.py    # TUI for cloning Blitzy-Sandbox org repos
  sync-submodules.py  # submodule updater (HTTPS→SSH rewrite)
  Makefile            # entry points
  bin/
    archie-sync       # run sync-submodules.py from anywhere
  nvim/               # neovim config (submodule: mivim)
  claude-config/      # Claude Code config (submodule)
  nvimcollab/         # real-time neovim collaboration prototype
    nvim-plugin/      # neovim sidecar client
    server/           # WebSocket relay server
    web/              # browser-based editor
```

## Submodules

| Submodule | Repo | Purpose |
|-----------|------|---------|
| `nvim/` | [mivim](https://github.com/montanaromi/mivim) | Neovim configuration |
| `claude-config/` | [claude-config](https://github.com/montanaromi/claude-config) | Claude Code settings |

## Shell Config

`setup.sh` installs these into `~/.zshrc` and `~/.shell-config.d/`:

- **Oh My Zsh** with `xiong-chiamiov-plus` theme
- **pyenv**, **nvm**, **cargo** PATH integrations
- **Journal system** (`journal`, `note`, `todo`, `todos` commands)
- Aliases: `vim`→`nvim`, `blitz`→`~/Lab/Work`, `sandbox`→`~/Lab/Sandbox`

## Ubuntu Autoinstall

For bare-metal Ubuntu installs (LUKS + LVM), there's an autoinstall config at `~/Lab/Utils/autoinstall/user-data` that handles disk encryption and user creation. After first boot, clone this repo and run `make setup`.
