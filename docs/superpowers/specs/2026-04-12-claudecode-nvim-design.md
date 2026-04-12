# Design: claudecode.nvim Integration

**Date:** 2026-04-12
**Status:** Approved

## Overview

Add `coder/claudecode.nvim` to the Neovim config. The plugin runs a pure-Lua WebSocket MCP server inside Neovim; the Claude Code CLI auto-connects via a lock file at `~/.claude/ide/<port>.lock`. Once connected, Claude has live access to open buffers, cursor position, visual selection, and LSP diagnostics — and can propose file diffs that are accepted or rejected entirely within Neovim.

## Architecture

One new file: `~/.config/nvim/lua/plugins/claudecode.lua`

Contains two lazy.nvim specs:

1. **`folke/snacks.nvim`** — loaded with all modules disabled except `terminal`. Used only as the terminal provider; does not interfere with catppuccin, lualine, bufferline, or any existing UI plugin.
2. **`coder/claudecode.nvim`** — declares snacks as a dependency. `auto_start = true` ensures the MCP WebSocket server is running as soon as Neovim opens, so the CLI connects instantly when you toggle the panel.

One addition to the existing `lua/plugins/whichkey.lua`: a `<leader>a` group ("AI (Claude)").

## Configuration

### snacks.nvim

Only the `terminal` module is enabled; everything else is explicitly set to `false` to keep the footprint minimal.

### claudecode.nvim

```
terminal.provider      = "snacks"
terminal.split_side    = "right"
terminal.split_width_percentage = 0.35

snacks_win_opts:
  position = "right"
  width    = 0.35
  height   = 1.0
  border   = "rounded"

diff.keep_terminal_focus = false   -- return focus to code buffer after accept/deny
auto_start               = true
log_level                = "info"
```

## Keymaps

All keymaps live inside the `claudecode.nvim` lazy spec's `keys` table.

| Key | Mode | Action |
|-----|------|--------|
| `<leader>ac` | n | Toggle Claude panel |
| `<leader>af` | n | Focus Claude panel |
| `<leader>as` | n, v | Add current file or selection to Claude context |
| `<leader>aa` | n | Accept proposed diff |
| `<leader>ad` | n | Deny proposed diff |

`<leader>` is `Space`. No conflicts with existing groups (`f`, `g`, `c`, `d`, `s`, `b`).

which-key addition: `{ "<leader>a", group = "AI (Claude)" }`

## Data Flow

1. Neovim starts → claudecode.nvim spins up WebSocket server, writes lock file
2. User presses `<leader>ac` → snacks terminal opens, `claude` CLI launches and reads lock file, connects over WebSocket
3. Claude passively receives: active buffer path, cursor position, visual selection on change
4. `<leader>as` → explicit `@file` add for the current file or visual selection
5. Claude proposes a change → `openDiff` MCP call → Neovim opens a vertical diff split
6. User presses `<leader>aa` / `<leader>ad` → diff applied or discarded, focus returns to code buffer
7. `getDiagnostics` → Claude reads LSP diagnostics on demand when asked

## Files Changed

| File | Change |
|------|--------|
| `lua/plugins/claudecode.lua` | New — snacks + claudecode specs |
| `lua/plugins/whichkey.lua` | Add `<leader>a` group |

## Out of Scope

- snacks modules beyond `terminal` (notifications, picker, etc.)
- External terminal provider (Alacritty/Kitty)
- codecompanion / avante / any other AI assistant plugin
