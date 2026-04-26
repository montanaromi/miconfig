#!/usr/bin/env bash
# setup.sh — provision a dev machine from scratch.
# Cross-platform (macOS + Ubuntu/Debian). Idempotent. Safe to re-run.
#
# Usage:
#   git clone https://github.com/montanaromi/miconfig.git ~/Lab/Utils/miconfig
#   cd ~/Lab/Utils/miconfig
#   ./setup.sh           # full setup
#   ./setup.sh --phase 3 # run only phase 3
set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────
PYTHON_VERSIONS=("3.12" "3.13")
PYTHON_GLOBAL="3.13"
NODE_VERSION="--lts"
ZSH_THEME="xiong-chiamiov-plus"
GIT_EMAIL="michael@blitzy.com"

# ─── Helpers ──────────────────────────────────────────────────────────
OS="$(uname -s)"
ARCH="$(uname -m)"
PHASE_FILTER="${2:-}"
RUN_PHASE="${1:-}"

# detect if user has full sudo (guest accounts may not)
HAS_SUDO=true
if ! sudo -n true 2>/dev/null; then
  # can't sudo without password — check if user is in sudo group
  if ! groups | grep -qE '\b(sudo|admin|wheel)\b'; then
    HAS_SUDO=false
  fi
fi

phase() {
  local num="$1" name="$2"
  if [[ "$RUN_PHASE" == "--phase" && "$PHASE_FILTER" != "$num" ]]; then
    return 1
  fi
  echo ""
  echo "━━━ Phase $num: $name ━━━"
  return 0
}

ok()   { echo "  ✓ $1"; }
skip() { echo "  · $1 (already installed)"; }
fail() { echo "  ✗ $1" >&2; }

has() { command -v "$1" &>/dev/null; }

# cross-platform sed in-place (BSD vs GNU)
sedi() {
  if [[ "$OS" == "Darwin" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# ─── Phase 1: System packages (requires sudo) ───────────────────────
if phase 1 "System packages" && [[ "$HAS_SUDO" == true ]]; then
  if [[ "$OS" == "Darwin" ]]; then
    if ! has brew; then
      echo "  Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      ok "Homebrew"
    else
      skip "Homebrew"
    fi
    brew bundle --no-lock --file=/dev/stdin <<BREWEOF
brew "git"
brew "curl"
brew "wget"
brew "zsh"
brew "neovim"
brew "tmux"
brew "htop"
brew "bat"
brew "ripgrep"
brew "fzf"
brew "tree"
brew "jq"
brew "yq"
brew "cloc"
brew "ranger"
brew "pspg"
brew "colordiff"
brew "gh"
brew "helm"
brew "k3d"
brew "kubectl"
BREWEOF
    ok "Homebrew packages"

  elif [[ "$OS" == "Linux" ]]; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
      build-essential git curl wget zsh neovim tmux htop bat ripgrep fzf tree jq \
      cloc ranger pspg colordiff openssh-server ufw unattended-upgrades \
      python3-pip python3-venv software-properties-common \
      libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
      libncursesw5-dev libffi-dev liblzma-dev tk-dev \
      apt-transport-https ca-certificates gnupg lsb-release
    ok "apt packages"

    # bat symlink (Ubuntu ships batcat)
    if [ -f /usr/bin/batcat ] && [ ! -f /usr/local/bin/bat ]; then
      sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
      ok "bat symlink"
    fi

    # yq (Go version — Ubuntu's is different)
    if ! has yq; then
      sudo curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" -o /usr/local/bin/yq
      sudo chmod +x /usr/local/bin/yq
      ok "yq"
    else
      skip "yq"
    fi
  fi
fi

# ─── Phase 2: Docker + cloud tools (Linux only, requires sudo) ───────
if phase 2 "Docker & cloud tools" && [[ "$HAS_SUDO" == true ]]; then
  if [[ "$OS" == "Linux" ]]; then
    # Docker
    if ! has docker; then
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo usermod -aG docker "$USER"
      ok "Docker"
    else
      skip "Docker"
    fi

    # GitHub CLI
    if ! has gh; then
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli.gpg > /dev/null
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq gh
      ok "GitHub CLI"
    else
      skip "GitHub CLI"
    fi

    # Google Cloud SDK
    if ! has gcloud; then
      curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/cloud.google.gpg
      echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq google-cloud-cli
      ok "Google Cloud SDK"
    else
      skip "Google Cloud SDK"
    fi

    # Azure CLI
    if ! has az; then
      curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --yes --dearmor -o /etc/apt/keyrings/microsoft.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/azure-cli.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq azure-cli
      ok "Azure CLI"
    else
      skip "Azure CLI"
    fi

    # 1Password
    if ! has op; then
      curl -fsSL https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --yes --dearmor -o /etc/apt/keyrings/1password.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/1password.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" | sudo tee /etc/apt/sources.list.d/1password.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq 1password
      ok "1Password"
    else
      skip "1Password"
    fi

    # .NET SDK
    if ! has dotnet; then
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/$(lsb_release -rs)/prod $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/dotnet.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq dotnet-sdk-8.0
      ok ".NET SDK 8"
    else
      skip ".NET SDK"
    fi

    # kubectl
    if ! has kubectl; then
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes.gpg
      echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq kubectl
      ok "kubectl"
    else
      skip "kubectl"
    fi

    # Helm
    if ! has helm; then
      curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      ok "Helm"
    else
      skip "Helm"
    fi

    # k3d
    if ! has k3d; then
      curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
      ok "k3d"
    else
      skip "k3d"
    fi

    # Java
    if ! has java; then
      sudo apt-get install -y -qq openjdk-21-jdk
      ok "OpenJDK 21"
    else
      skip "Java"
    fi

    # Firewall
    sudo ufw allow ssh 2>/dev/null || true
    sudo ufw --force enable 2>/dev/null || true
    ok "UFW"

  elif [[ "$OS" == "Darwin" ]]; then
    # macOS gets Docker Desktop, gcloud, etc. via cask or manual install
    echo "  · macOS: install Docker Desktop, gcloud SDK, and Azure CLI manually or via brew cask"
  fi
fi

# ─── Phase 3: Languages (pyenv, nvm, rust, go) ───────────────────────
if phase 3 "Languages"; then
  # Go (requires sudo for /usr/local install)
  if ! has go; then
    if [[ "$HAS_SUDO" == true ]]; then
      GO_VERSION=$(curl -fsSL https://go.dev/VERSION?m=text | head -1)
      if [[ "$OS" == "Darwin" ]]; then
        GO_ARCH="darwin-arm64"
        [[ "$ARCH" == "x86_64" ]] && GO_ARCH="darwin-amd64"
      else
        GO_ARCH="linux-amd64"
      fi
      curl -fsSL "https://go.dev/dl/${GO_VERSION}.${GO_ARCH}.tar.gz" | sudo tar -C /usr/local -xzf -
      export PATH="$PATH:/usr/local/go/bin"
      echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' | sudo tee /etc/profile.d/golang.sh > /dev/null 2>/dev/null || true
      ok "Go ($GO_VERSION)"
    else
      skip "Go (needs sudo)"
    fi
  else
    skip "Go ($(go version | awk '{print $3}'))"
  fi

  # pyenv
  if [ ! -d "$HOME/.pyenv" ]; then
    curl -fsSL https://pyenv.run | bash
    ok "pyenv"
  else
    skip "pyenv"
  fi
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)" 2>/dev/null || true

  for ver in "${PYTHON_VERSIONS[@]}"; do
    if ! pyenv versions --bare | grep -q "^${ver}"; then
      pyenv install -s "$ver"
      ok "Python $ver"
    else
      skip "Python $ver"
    fi
  done
  pyenv global "$PYTHON_GLOBAL"

  # nvm
  if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
    ok "nvm"
  else
    skip "nvm"
  fi
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  if ! nvm ls --no-colors "$NODE_VERSION" &>/dev/null; then
    nvm install "$NODE_VERSION"
    ok "Node.js LTS"
  else
    skip "Node.js LTS"
  fi

  # Rust
  if ! has rustc; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    ok "Rust"
  else
    skip "Rust ($(rustc --version | awk '{print $2}'))"
  fi
fi

# ─── Phase 4: Shell ──────────────────────────────────────────────────
if phase 4 "Shell"; then
  # zsh as default
  if [[ "$SHELL" != */zsh ]]; then
    if [[ "$HAS_SUDO" == true ]]; then
      sudo chsh -s "$(which zsh)" "$USER"
      ok "Default shell → zsh"
    else
      skip "zsh default shell (needs sudo, run: chsh -s $(which zsh))"
    fi
  else
    skip "zsh default shell"
  fi

  # Oh My Zsh
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh"
  else
    skip "Oh My Zsh"
  fi

  # Theme
  if grep -q 'ZSH_THEME="robbyrussell"' "$HOME/.zshrc" 2>/dev/null; then
    sedi "s/ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"$ZSH_THEME\"/" "$HOME/.zshrc"
    ok "Theme → $ZSH_THEME"
  else
    skip "ZSH theme"
  fi

  # Append shell integrations (only if not already present)
  if ! grep -q "# miconfig-managed" "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" << 'ZSHEOF'

# miconfig-managed — do not edit between these markers
# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# cargo/rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# custom shell configs
for f in ~/.shell-config.d/*.sh; do [ -r "$f" ] && source "$f"; done

# aliases
alias vim="nvim"
alias ec="vim ~/.zshrc"
alias sc="source ~/.zshrc"
alias blitz="cd $HOME/Lab/Work"
alias sandbox="cd $HOME/Lab/Sandbox"
alias generate-uuid="uuidgen | tr '[:upper:]' '[:lower:]'"
# end miconfig-managed
ZSHEOF
    ok ".zshrc integrations"
  else
    skip ".zshrc integrations"
  fi

  # SSH key
  if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""
    ok "SSH key"
  else
    skip "SSH key"
  fi
fi

# ─── Phase 5: Directories & dotfiles ─────────────────────────────────
if phase 5 "Directories"; then
  for dir in Lab/Work Lab/Sandbox Lab/Utils notes .shell-config.d bin; do
    mkdir -p "$HOME/$dir"
  done
  ok "~/Lab/{Work,Sandbox,Utils}, ~/notes, ~/bin"

  # Journal system
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -f "$SCRIPT_DIR/shell-config.d/journal.sh" ]; then
    cp "$SCRIPT_DIR/shell-config.d/journal.sh" "$HOME/.shell-config.d/journal.sh"
    ok "journal.sh (from repo)"
  elif [ ! -f "$HOME/.shell-config.d/journal.sh" ]; then
    cat > "$HOME/.shell-config.d/journal.sh" << 'JOURNALEOF'
_journal_file() {
  local today=$(date +%Y-%m-%d) year=$(date +%Y) month=$(date +%m) dayname=$(date +%A)
  local dir="$HOME/notes/$year/$month" file="$dir/$today.md"
  if [[ ! -f "$file" ]]; then
    mkdir -p "$dir"
    printf "# %s - %s\n\n## Notes\n\n## Todos\n" "$today" "$dayname" > "$file"
  fi
  echo "$file"
}
note() {
  [[ -z "$*" ]] && echo "Usage: note <text>" && return 1
  local file=$(_journal_file) ts=$(date +%H:%M)
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "/^## Todos$/i\\
- [$ts] $*
" "$file"
  else
    sed -i "/^## Todos$/i\\- [$ts] $*" "$file"
  fi
  echo "Note added: [$ts] $*"
}
todo() {
  if [[ "${1:-}" =~ ^-([0-9]+)$ ]]; then local n="${BASH_REMATCH[1]:-${match[1]}}"; shift; _todo_status "$n" "$@"; return; fi
  [[ -z "$*" ]] && echo "Usage: todo <text>" && return 1
  echo "- [TODO] $*" >> "$(_journal_file)"
  echo "Todo added: $*"
}
todos() {
  local file=$(_journal_file) num=0
  grep -n '^\- \[' "$file" | grep -E '\[(TODO|DONE|IN_PROGRESS|BLOCKED)\]' | while IFS= read -r line; do
    num=$((num + 1))
    local c=""; [[ "$line" == *'[TODO]'* ]] && c="\033[33m"; [[ "$line" == *'[IN_PROGRESS]'* ]] && c="\033[34m"
    [[ "$line" == *'[DONE]'* ]] && c="\033[32m"; [[ "$line" == *'[BLOCKED]'* ]] && c="\033[31m"
    echo -e "  ${c}${num}. ${line#*:}\033[0m"
  done
}
_todo_status() {
  local num="$1" new_status="${2^^}"
  [[ -z "$new_status" ]] && echo "Statuses: todo, done, in_progress, blocked" && return 1
  case "$new_status" in TODO|DONE|IN_PROGRESS|BLOCKED) ;; *) echo "Invalid: $new_status"; return 1;; esac
  local file=$(_journal_file) tmp=$(mktemp)
  awk -v n="$num" -v s="$new_status" '/^- \[(TODO|DONE|IN_PROGRESS|BLOCKED)\]/{c++;if(c==n)sub(/\[(TODO|DONE|IN_PROGRESS|BLOCKED)\]/,"["s"]")}{print}' "$file" > "$tmp" && mv "$tmp" "$file"
  echo "Todo #$num -> [$new_status]"
}
alias journal='vim $(_journal_file)'
JOURNALEOF
    ok "journal.sh (generated)"
  else
    skip "journal.sh"
  fi
fi

# ─── Phase 6: Snaps (Linux only, requires sudo) ─────────────────────
if phase 6 "Desktop apps" && [[ "$HAS_SUDO" == true ]]; then
  if [[ "$OS" == "Linux" ]] && has snap; then
    for app in firefox spotify; do
      snap list "$app" &>/dev/null && skip "$app" && continue
      sudo snap install "$app" && ok "$app"
    done
    for app in slack postman pycharm-professional; do
      snap list "$app" &>/dev/null && skip "$app" && continue
      sudo snap install "$app" --classic && ok "$app"
    done
  elif [[ "$OS" == "Darwin" ]]; then
    echo "  · macOS: install desktop apps via App Store or brew cask"
  fi
fi

# ─── Done ─────────────────────────────────────────────────────────────
echo ""
echo "━━━ Done ━━━"
echo ""
echo "  SSH public key:"
cat "$HOME/.ssh/id_ed25519.pub" 2>/dev/null || echo "  (none generated)"
echo ""
echo "  Add to GitHub: https://github.com/settings/ssh/new"
echo "  Then run: make install"
echo ""
if [[ "$OS" == "Linux" ]]; then
  echo "  Log out and back in for docker group + zsh to take effect."
fi
echo "  Log: $HOME/post-install.log (if redirected)"
