# Neovim Config with LSP — Design Spec

**Date:** 2026-04-11  
**Status:** Approved

---

## Overview

A full-featured Neovim configuration targeting professional use across Python, Rust, Go, TypeScript, Lua, and C/C++. Built on `lazy.nvim` for plugin management and `mason.nvim` for LSP/tool installation. Organized using lazy.nvim's idiomatic plugin-per-file structure for maintainability and scalability.

---

## Directory Structure

```
~/.config/nvim/
├── init.lua                  # bootstraps lazy.nvim, loads core options/keymaps
├── lua/
│   ├── core/
│   │   ├── options.lua       # vim.opt settings
│   │   └── keymaps.lua       # global keybindings
│   ├── plugins/
│   │   ├── ui.lua            # colorscheme (catppuccin), lualine, bufferline
│   │   ├── telescope.lua     # fuzzy finder + fzf-native extension
│   │   ├── treesitter.lua    # syntax highlighting + text objects
│   │   ├── filetree.lua      # neo-tree
│   │   ├── git.lua           # gitsigns + lazygit
│   │   ├── autopairs.lua     # nvim-autopairs
│   │   ├── whichkey.lua      # which-key
│   │   ├── dap.lua           # nvim-dap + nvim-dap-ui + mason-nvim-dap
│   │   └── completion.lua    # nvim-cmp + luasnip + friendly-snippets
│   └── lsp/
│       ├── init.lua          # mason + mason-lspconfig bootstrap
│       ├── handlers.lua      # shared on_attach, capabilities
│       └── servers.lua       # per-language server config
```

`init.lua` is the sole entry point. It requires `core/options` and `core/keymaps`, bootstraps lazy.nvim (self-cloning from GitHub on first run), then lazy auto-discovers all specs under `lua/plugins/`.

---

## Plugin List

| Category | Plugin(s) |
|---|---|
| Plugin manager | `lazy.nvim` |
| LSP installer | `mason.nvim` + `mason-lspconfig.nvim` |
| LSP engine | `nvim-lspconfig` |
| Completion | `nvim-cmp` + `cmp-nvim-lsp` + `cmp-buffer` + `cmp-path` + `luasnip` + `friendly-snippets` |
| Syntax | `nvim-treesitter` (auto-install parsers) |
| Fuzzy finder | `telescope.nvim` + `telescope-fzf-native` |
| File tree | `neo-tree.nvim` |
| Git | `gitsigns.nvim` + `lazygit.nvim` |
| Statusline | `lualine.nvim` |
| Bufferline | `bufferline.nvim` |
| Colorscheme | `catppuccin` |
| Debugging | `nvim-dap` + `nvim-dap-ui` + `mason-nvim-dap` |
| Keybind hints | `which-key.nvim` |
| Auto-pairs | `nvim-autopairs` |
| Comments | `Comment.nvim` |
| Formatting | `conform.nvim` |

---

## LSP Servers (via mason)

| Language | Server |
|---|---|
| Python | `pyright` |
| Rust | `rust_analyzer` |
| Go | `gopls` |
| TypeScript/JS | `ts_ls` |
| Lua | `lua_ls` |
| C/C++ | `clangd` |

---

## Formatters/Linters (via mason + conform.nvim)

| Language | Tool |
|---|---|
| Python | `black` |
| Rust | `rustfmt` |
| Go | `gofmt` |
| TypeScript/JS | `prettier` |
| Lua | `stylua` |
| C/C++ | `clang-format` |

Format-on-save is enabled via `conform.nvim` on `BufWritePre`.

---

## Data Flow

### Startup Sequence
1. `init.lua` sets options and keymaps
2. lazy.nvim bootstraps itself (auto-clones from GitHub if missing)
3. lazy.nvim discovers and loads all `lua/plugins/*.lua` specs
4. On first run, mason installs all declared servers, formatters, and DAP adapters automatically

### LSP Wiring
- `mason-lspconfig` bridges mason installs → `nvim-lspconfig` setup calls
- All servers share a common `on_attach` (in `lsp/handlers.lua`) setting buffer-local keymaps:
  - `gd` — go-to-definition
  - `K` — hover documentation
  - `<leader>rn` — rename symbol
  - `<leader>ca` — code action
  - `[d` / `]d` — previous/next diagnostic
- `cmp-nvim-lsp` extends server capabilities so completions flow LSP → nvim-cmp → UI

### Completion Chain
LSP completions + buffer words + file paths are ranked and displayed by `nvim-cmp`. `luasnip` handles snippet expansion via `<Tab>`.

### Debugging
- `mason-nvim-dap` installs debug adapters alongside LSP servers
- `nvim-dap-ui` opens automatically when a debug session starts
- Keymaps: `<F5>` continue, `<F10>` step over, `<F11>` step into, `<F12>` step out

---

## Error Handling & Bootstrap

**First-run resilience:**
- lazy.nvim self-bootstraps by cloning from GitHub if `~/.local/share/nvim/lazy/lazy.nvim` is absent
- mason auto-installs all declared servers/tools via `ensure_installed` on first open
- Failed server installs are non-fatal — Neovim opens cleanly, LSP simply won't attach for that filetype

**No config crash on missing plugins:**
- All plugin config runs inside lazy.nvim `config`/`opts` callbacks — only executes after the plugin is confirmed loaded

**Updating:**
- `:Lazy update` — updates all plugins
- `:MasonUpdate` — updates all installed LSP servers and tools

**Validation:**
- `:checkhealth` — confirms zero errors for mason, LSP, treesitter, and telescope
