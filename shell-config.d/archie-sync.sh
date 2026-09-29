# archie-sync — sync the current git repo and its submodules to a branch.
#
#   archie-sync              sync submodules to their tracked branches
#   archie-sync qa           put the repo + all submodules on qa
#   archie-sync qa --stash   stash uncommitted work first, restore after
#   archie-sync qa --no-parent   submodules only
#
# Exposed as a shell function so it works without ~/.local/bin on PATH. The
# discovery below locates miconfig's script only; the sync acts on whatever
# repo the cwd belongs to. Override discovery with MICONFIG_ROOT.

_archie_miconfig_root() {
  local candidate link target

  # 1. Explicit override.
  if [ -n "${MICONFIG_ROOT:-}" ] && [ -f "$MICONFIG_ROOT/bin/archie-sync" ]; then
    printf '%s\n' "$MICONFIG_ROOT"
    return 0
  fi

  # 2. The symlink install.py drops in the user bin dir points at the real repo.
  link="$HOME/.local/bin/archie-sync"
  if [ -L "$link" ]; then
    target="$(readlink "$link")"
    case "$target" in
      /*) ;;
       *) target="$(dirname "$link")/$target" ;;
    esac
    target="$(cd "$(dirname "$target")/.." 2>/dev/null && pwd)"
    if [ -n "$target" ] && [ -f "$target/bin/archie-sync" ]; then
      printf '%s\n' "$target"
      return 0
    fi
  fi

  # 3. Common clone locations.
  for candidate in \
    "$HOME/Lab/Utils/miconfig" \
    "$HOME/Lab/Blitzy/miconfig" \
    "$HOME/Lab/miconfig" \
    "$HOME/miconfig"
  do
    if [ -f "$candidate/bin/archie-sync" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

archie-sync() {
  local root py
  if ! root="$(_archie_miconfig_root)"; then
    echo "archie-sync: could not locate the miconfig repo." >&2
    echo "  Set MICONFIG_ROOT=/path/to/miconfig, or re-run 'python install.py'." >&2
    return 1
  fi

  if ! py="$(command -v python3 || command -v python)"; then
    echo "archie-sync: no python3 on PATH." >&2
    return 1
  fi

  # cwd is passed through untouched: the sync targets the repo you're in.
  "$py" "$root/bin/archie-sync" "$@"
}
