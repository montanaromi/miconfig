#!/usr/bin/env bash
# guest.sh — create a guest dev account with limited sudo.
# Prompts for name and password, creates agent-<name>, runs setup.sh as that user.
#
# Usage:
#   make guest
#   make guest NAME=fde  # skip the name prompt
set -euo pipefail

NAME="${NAME:-}"

if [[ -z "$NAME" ]]; then
  read -rp "Guest name (will become agent-<name>): " NAME
fi

if [[ -z "$NAME" ]]; then
  echo "No name provided." >&2
  exit 1
fi

USERNAME="agent-${NAME}"

# Check if user already exists
if id "$USERNAME" &>/dev/null; then
  echo "User $USERNAME already exists."
  read -rp "Re-run setup for $USERNAME? [y/N]: " rerun
  if [[ "$rerun" =~ ^[Yy]$ ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    sudo -u "$USERNAME" bash "$SCRIPT_DIR/setup.sh"
  fi
  exit 0
fi

# Password
read -rsp "Password for $USERNAME: " PASS
echo ""
read -rsp "Confirm: " PASS2
echo ""

if [[ "$PASS" != "$PASS2" ]]; then
  echo "Passwords don't match." >&2
  exit 1
fi

# Ensure zsh is available
ZSH_PATH="$(which zsh 2>/dev/null || echo /usr/bin/zsh)"
if [ ! -x "$ZSH_PATH" ]; then
  echo "zsh not found. Run 'make setup' first." >&2
  exit 1
fi

# Create user
sudo useradd -m -s "$ZSH_PATH" -G users "$USERNAME"
echo "$USERNAME:$PASS" | sudo chpasswd

# Add to docker group if it exists
getent group docker &>/dev/null && sudo usermod -aG docker "$USERNAME"

# Limited sudo: apt and snap only
echo "$USERNAME ALL=(ALL) NOPASSWD:/usr/bin/apt,/usr/bin/apt-get,/usr/bin/snap" | sudo tee "/etc/sudoers.d/$USERNAME" > /dev/null
sudo chmod 440 "/etc/sudoers.d/$USERNAME"

echo ""
echo "✓ Created $USERNAME with limited sudo (apt, snap)"
echo ""

# Run setup as the new user
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
read -rp "Run setup.sh as $USERNAME now? [Y/n]: " run_setup
if [[ ! "$run_setup" =~ ^[Nn]$ ]]; then
  # Clone miconfig into guest's home and run setup
  GUEST_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)
  sudo -u "$USERNAME" mkdir -p "$GUEST_HOME/Lab/Utils"
  sudo -u "$USERNAME" cp -r "$SCRIPT_DIR" "$GUEST_HOME/Lab/Utils/miconfig"
  sudo -u "$USERNAME" bash "$GUEST_HOME/Lab/Utils/miconfig/setup.sh"
fi
