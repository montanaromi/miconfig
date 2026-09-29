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

# Does the toolchain actually produce a binary? `cc -v` only starts the driver
# and still succeeds when the selected SDK is unusable, so link a real program.
cc_links() {
  local d rc=0
  d="$(mktemp -d)"
  printf 'int main(void){return 0;}\n' >"$d/t.c"
  cc "$d/t.c" -o "$d/t" &>/dev/null || rc=1
  rm -rf "$d"
  return "$rc"
}

# Verify the toolchain can link, and repair the common cause when we can.
#
# An SDK left behind by a beta toolchain outranks the CLT's own SDK in
# `xcrun --sdk macosx --show-sdk-path` — which ignores SDKROOT, and is what
# python-build bakes into CFLAGS/LDFLAGS as -isysroot. If that SDK's .tbd stubs
# are newer than the shipping linker can parse, every link dies with "tapi
# error: malformed file", which configure reports as the misleading "C compiler
# cannot create executables".
#
# Quarantining the stale SDK needs sudo, but the diagnosis does not — so a
# non-sudo run still gets told exactly what is wrong and what to move.
TOOLCHAIN_CHECKED=false
check_toolchain() {
  [[ "$OS" != "Darwin" || "$TOOLCHAIN_CHECKED" == true ]] && return 0
  TOOLCHAIN_CHECKED=true

  local SDK_DIR="/Library/Developer/CommandLineTools/SDKs"
  local default_sdk default_ver quarantine sdk name ver

  if cc_links; then
    ok "Toolchain links (SDK: $(xcrun --sdk macosx --show-sdk-path 2>/dev/null))"
    return 0
  fi

  default_sdk="$(readlink "$SDK_DIR/MacOSX.sdk" 2>/dev/null || true)"
  if [[ -n "$default_sdk" ]] && SDKROOT="$SDK_DIR/$default_sdk" cc_links; then
    default_ver="${default_sdk#MacOSX}"; default_ver="${default_ver%.sdk}"
    echo "  Toolchain cannot link; CLT default SDK is $default_sdk."

    if [[ "$HAS_SUDO" == true ]]; then
      quarantine="$HOME/.miconfig/stale-sdks"
      mkdir -p "$quarantine"
      for sdk in "$SDK_DIR"/MacOSX*.sdk; do
        name="$(basename "$sdk")"
        ver="${name#MacOSX}"; ver="${ver%.sdk}"
        [[ -z "$ver" || "$ver" == "$default_ver" ]] && continue
        # keep every SDK that is not newer than the CLT's own
        [[ "$(printf '%s\n%s\n' "$ver" "$default_ver" | sort -V | tail -1)" == "$default_ver" ]] && continue
        sudo mv "$sdk" "$quarantine/" && echo "  · quarantined $name -> $quarantine/$name"
      done
    else
      fail "A stale SDK newer than $default_sdk is shadowing the CLT's own."
      fail "No sudo here, so run this by hand, then re-run setup:"
      for sdk in "$SDK_DIR"/MacOSX*.sdk; do
        name="$(basename "$sdk")"
        ver="${name#MacOSX}"; ver="${ver%.sdk}"
        [[ -z "$ver" || "$ver" == "$default_ver" ]] && continue
        [[ "$(printf '%s\n%s\n' "$ver" "$default_ver" | sort -V | tail -1)" == "$default_ver" ]] && continue
        fail "  sudo mv $sdk ~/.miconfig/stale-sdks/"
      done
    fi
  fi

  if ! cc_links; then
    fail "Toolchain cannot create executables. Debug with:"
    fail "  xcrun --sdk macosx --show-sdk-path   # SDK the linker will use"
    fail "  echo 'int main(void){return 0;}' > /tmp/t.c && cc /tmp/t.c -o /tmp/t"
    exit 1
  fi
  ok "Toolchain links (SDK: $(xcrun --sdk macosx --show-sdk-path 2>/dev/null))"
}

# Install one cask, saying *why* it failed.
#
# The bare `brew install --cask X && ok || fail X` form collapses a dead cask
# name, an app already sitting in /Applications, and a network blip into one
# identical line — which is how a valid cask reads as "doesn't exist". Preflight
# the name so an unknown cask is named as such and never mistaken for the rest.
#
# Accumulators are strings, not arrays: macOS bash 3.2 + `set -u` treats
# ${arr[@]} on an empty array as an unbound variable. Always returns 0 so a
# single bad name cannot trip `set -e` and abort the remaining installs.
CASK_UNKNOWN=""
CASK_FAILED=""
cask_install() {
  local app="$1" out err
  if brew list --cask "$app" &>/dev/null; then
    skip "$app"
    return 0
  fi
  if ! brew info --cask "$app" &>/dev/null; then
    fail "$app — no such cask (renamed, or needs a third-party tap)"
    CASK_UNKNOWN="$CASK_UNKNOWN $app"
    return 0
  fi
  if out="$(brew install --cask "$app" 2>&1)"; then
    ok "$app"
    return 0
  fi
  if printf '%s' "$out" | grep -q "already an App at"; then
    fail "$app — already in /Applications, but not brew-managed"
    fail "    adopt it with: brew install --cask --adopt $app"
  else
    err="$(printf '%s' "$out" | grep -i 'error' | head -1)"
    fail "$app — install failed${err:+: $err}"
  fi
  CASK_FAILED="$CASK_FAILED $app"
  return 0
}

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
    if ! cc -v &>/dev/null; then
      echo "  Installing Xcode Command Line Tools (gcc, make, git)..."
      xcode-select --install
      echo "  Waiting for Xcode CLT install to finish (GUI prompt)..."
      until cc -v &>/dev/null; do sleep 5; done
      ok "Xcode Command Line Tools"
    else
      skip "Xcode Command Line Tools"
    fi
    sudo xcodebuild -license accept 2>/dev/null || true

    check_toolchain

    if ! has brew; then
      echo "  Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      ok "Homebrew"
    else
      skip "Homebrew"
    fi
    # Ensure brew is on PATH (fresh install won't have shell config yet)
    if ! has brew; then
      if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi
    brew bundle --file=/dev/stdin <<BREWEOF || true
brew "git"
brew "git-lfs"
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
brew "duti"
brew "gh"
brew "helm"
brew "k3d"
brew "kubectl"
brew "bore-cli"
brew "ffmpeg"
brew "llama.cpp"
brew "mdcat"
brew "pandoc"
brew "postgresql@14"
brew "railway"
brew "redis"
brew "flyctl"
brew "dotnet@8"
brew "openjdk@21"
brew "powershell"
BREWEOF
    brew_missing=()
    for pkg in git git-lfs curl wget zsh neovim tmux htop bat ripgrep fzf tree jq yq cloc ranger pspg colordiff duti gh helm k3d kubectl bore-cli ffmpeg llama.cpp mdcat pandoc postgresql@14 railway redis flyctl dotnet@8 openjdk@21 powershell; do
      brew list "$pkg" &>/dev/null || brew_missing+=("$pkg")
    done
    if [[ ${#brew_missing[@]} -gt 0 ]]; then
      fail "Missing Homebrew packages: ${brew_missing[*]}"
      exit 1
    fi
    ok "Homebrew packages"

  elif [[ "$OS" == "Linux" ]]; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
      build-essential git curl wget zsh neovim tmux htop bat ripgrep fzf tree jq \
      cloc ranger pspg colordiff openssh-server ufw unattended-upgrades \
      python3-pip python3-venv software-properties-common \
      libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
      libncursesw5-dev libffi-dev liblzma-dev tk-dev \
      apt-transport-https ca-certificates gnupg lsb-release \
      ffmpeg pandoc redis-server
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

# ─── Phase 2: Docker & infrastructure (Linux, requires sudo) ────────
if phase 2 "Docker & infrastructure" && [[ "$HAS_SUDO" == true ]]; then
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

    # Firewall
    sudo ufw allow ssh 2>/dev/null || true
    sudo ufw --force enable 2>/dev/null || true
    ok "UFW"
  fi
fi

# ─── Phase 3: Languages (pyenv, nvm, rust, go) ───────────────────────
if phase 3 "Languages"; then
  # pyenv builds Python from source, so a broken linker surfaces here as a
  # bogus "C compiler cannot create executables". Phase 1 is skipped entirely
  # without sudo, so check again — the guard makes this a no-op if it already ran.
  check_toolchain

  # Go — brew on macOS: no sudo needed, and it lands on PATH. The Linux path
  # below relies on /etc/profile.d, which macOS has no equivalent for (no /etc
  # zsh startup file sources it), so a tarball install there is invisible.
  if ! has go; then
    if [[ "$OS" == "Darwin" ]]; then
      brew install go
      ok "Go ($(go version | awk '{print $3}'))"
    elif [[ "$HAS_SUDO" == true ]]; then
      GO_VERSION=$(curl -fsSL https://go.dev/VERSION?m=text | head -1)
      GO_ARCH="linux-amd64"
      [[ "$ARCH" == "aarch64" ]] && GO_ARCH="linux-arm64"
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
      # python-build prints nothing between "use zlib from xcode sdk" and
      # "Installed Python-..." — a compile that looks like a hang. Say so, so
      # nobody kills a build that is 60s from finishing.
      echo "  Building Python $ver from source (~2 min, silent while compiling)..."
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
  # nvm conflicts with npmrc prefix — remove it before loading nvm
  if [ -f "$HOME/.npmrc" ] && grep -q '^prefix=' "$HOME/.npmrc"; then
    sedi '/^prefix=/d' "$HOME/.npmrc"
  fi
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

  # Shell drop-ins from the repo (journal.sh, archie-sync.sh, ...)
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -d "$SCRIPT_DIR/shell-config.d" ]; then
    for f in "$SCRIPT_DIR"/shell-config.d/*.sh; do
      [ -r "$f" ] || continue
      cp "$f" "$HOME/.shell-config.d/$(basename "$f")"
      ok "$(basename "$f") (from repo)"
    done
  fi

  # Journal fallback for a checkout without the repo drop-ins
  if [ ! -f "$HOME/.shell-config.d/journal.sh" ]; then
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

# ─── Phase 6: Optional extras (Apps / Cloud / Fonts) ────────────────
if phase 6 "Optional extras"; then
  if [[ -n "${MICONFIG_EXTRAS:-}" ]]; then
    cat_input="$MICONFIG_EXTRAS"
  elif [[ -t 0 ]]; then
    echo ""
    echo "  Select categories to install (comma-separated):"
    echo "    [A] Apps   — 1Password, Docker Desktop, Slack, Arc, Figma, Postman, ..."
    echo "    [C] Cloud  — Google Cloud SDK, Azure CLI, Vercel CLI, .NET SDK"
    echo "    [F] Fonts  — Fira Code, JetBrains Mono, Roboto, Noto, ..."
    echo ""
    echo "    [all]  All categories"
    echo "    [none] Skip"
    echo ""
    read -rp "  Categories [A,C,F]: " cat_input
  else
    echo "  Non-interactive — skipping optional extras."
    echo "  Set MICONFIG_EXTRAS='a,c,f' or 'all' to install."
    cat_input="none"
  fi

  # tr, not ${x,,} — macOS ships bash 3.2, where that expansion is a syntax error
  cat_input="$(printf '%s' "$cat_input" | tr '[:upper:]' '[:lower:]')"

  INSTALL_APPS=false
  INSTALL_CLOUD=false
  INSTALL_FONTS=false

  if [[ "$cat_input" == "all" ]]; then
    INSTALL_APPS=true; INSTALL_CLOUD=true; INSTALL_FONTS=true
  elif [[ "$cat_input" != "none" && -n "$cat_input" ]]; then
    [[ "$cat_input" == *"a"* ]] && INSTALL_APPS=true
    [[ "$cat_input" == *"c"* ]] && INSTALL_CLOUD=true
    [[ "$cat_input" == *"f"* ]] && INSTALL_FONTS=true
  fi

  # ── Apps ──
  if [[ "$INSTALL_APPS" == true ]]; then
    echo ""
    echo "  ── Apps ──"
    if [[ "$OS" == "Darwin" ]]; then
      CASK_APPS=(1password docker iterm2 arc slack spotify postman jetbrains-toolbox figma claude claude-code utm ngrok git-credential-manager)
      for app in "${CASK_APPS[@]}"; do
        cask_install "$app"
      done
      if ! brew list 1password-cli &>/dev/null; then
        brew install 1password-cli && ok "1password-cli"
      else
        skip "1password-cli"
      fi

    elif [[ "$OS" == "Linux" ]] && [[ "$HAS_SUDO" == true ]]; then
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
      # Snap apps
      if has snap; then
        for app in firefox spotify; do
          snap list "$app" &>/dev/null && skip "$app" && continue
          sudo snap install "$app" && ok "$app"
        done
        for app in slack postman pycharm-professional; do
          snap list "$app" &>/dev/null && skip "$app" && continue
          sudo snap install "$app" --classic && ok "$app"
        done
      fi
    fi
  fi

  # ── Cloud ──
  if [[ "$INSTALL_CLOUD" == true ]]; then
    echo ""
    echo "  ── Cloud ──"
    if [[ "$OS" == "Darwin" ]]; then
      cask_install gcloud-cli
      if ! brew list azure-cli &>/dev/null; then
        brew install azure-cli && ok "Azure CLI"
      else
        skip "Azure CLI"
      fi
      if ! brew list vercel-cli &>/dev/null; then
        brew install vercel-cli && ok "Vercel CLI"
      else
        skip "Vercel CLI"
      fi

    elif [[ "$OS" == "Linux" ]] && [[ "$HAS_SUDO" == true ]]; then
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
      # .NET SDK
      if ! has dotnet; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/$(lsb_release -rs)/prod $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/dotnet.list > /dev/null
        sudo apt-get update -qq
        sudo apt-get install -y -qq dotnet-sdk-8.0
        ok ".NET SDK 8"
      else
        skip ".NET SDK"
      fi
      # Vercel CLI
      if ! has vercel; then
        npm install -g vercel && ok "Vercel CLI" || fail "Vercel CLI"
      else
        skip "Vercel CLI"
      fi
    fi
    echo ""
    echo "  After install, authenticate with:"
    echo "    gcloud auth login"
    echo "    az login"
    echo "    gh auth login"
  fi

  # ── Fonts ──
  if [[ "$INSTALL_FONTS" == true ]]; then
    echo ""
    echo "  ── Fonts ──"
    if [[ "$OS" == "Darwin" ]]; then
      FONT_CASKS=(font-fira-code font-jetbrains-mono font-roboto font-roboto-mono font-noto-sans font-noto-sans-mono font-noto-serif font-open-sans font-lato font-inconsolata)
      for font in "${FONT_CASKS[@]}"; do
        cask_install "$font"
      done
    elif [[ "$OS" == "Linux" ]] && [[ "$HAS_SUDO" == true ]]; then
      sudo apt-get install -y -qq \
        fonts-firacode fonts-jetbrains-mono fonts-roboto fonts-noto \
        fonts-open-sans fonts-lato 2>/dev/null || true
      ok "System fonts"
    fi
  fi

  # Casks scroll past in a wall of output, so restate what did not land.
  if [[ -n "$CASK_UNKNOWN" || -n "$CASK_FAILED" ]]; then
    echo ""
    echo "  ── Casks needing attention ──"
    [[ -n "$CASK_UNKNOWN" ]] && fail "unknown cask(s):$CASK_UNKNOWN — fix the name in CASK_APPS or install by hand"
    [[ -n "$CASK_FAILED" ]] && fail "failed to install:$CASK_FAILED — see the error above each"
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
