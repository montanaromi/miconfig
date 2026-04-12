# claudecode.nvim Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `coder/claudecode.nvim` to the Neovim config so the Claude Code CLI connects to Neovim over WebSocket and can see buffers, selections, and LSP diagnostics, with diffs accepted/rejected in-editor.

**Architecture:** A new plugin file adds `folke/snacks.nvim` (terminal module only) and `coder/claudecode.nvim`. snacks provides the floating right-panel terminal; claudecode runs a WebSocket MCP server in Neovim that the CLI auto-connects to via a lock file. Keymaps live in the lazy spec's `keys` table; a which-key group is added for discoverability.

**Tech Stack:** Neovim 0.12.1, lazy.nvim, snacks.nvim (terminal only), coder/claudecode.nvim, Claude Code CLI (already installed at `claude`)

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `~/.config/nvim/lua/plugins/claudecode.lua` | Create | snacks.nvim (terminal-only) + claudecode.nvim specs, keymaps |
| `~/.config/nvim/lua/plugins/whichkey.lua` | Modify | Add `<leader>a` → "AI (Claude)" group |

---

### Task 1: Create claudecode.lua plugin spec

**Files:**
- Create: `~/.config/nvim/lua/plugins/claudecode.lua`

- [ ] **Step 1: Verify the file does not already exist**

```bash
ls ~/.config/nvim/lua/plugins/claudecode.lua 2>/dev/null && echo "EXISTS" || echo "OK to create"
```

Expected: `OK to create`

- [ ] **Step 2: Write the plugin spec**

Create `~/.config/nvim/lua/plugins/claudecode.lua` with this exact content:

```lua
-- ~/.config/nvim/lua/plugins/claudecode.lua
return {
  -- snacks.nvim: only the terminal module is enabled
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      bigfile      = { enabled = false },
      dashboard    = { enabled = false },
      explorer     = { enabled = false },
      indent       = { enabled = false },
      input        = { enabled = false },
      notifier     = { enabled = false },
      picker       = { enabled = false },
      quickfile    = { enabled = false },
      scroll       = { enabled = false },
      statuscolumn = { enabled = false },
      words        = { enabled = false },
      terminal     = { enabled = true },
    },
  },

  -- claudecode.nvim: MCP WebSocket server + Claude Code terminal
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    opts = {
      auto_start = true,
      log_level  = "info",
      terminal = {
        provider               = "snacks",
        split_side             = "right",
        split_width_percentage = 0.35,
        snacks_win_opts = {
          position = "right",
          width    = 0.35,
          height   = 1.0,
          border   = "rounded",
        },
      },
      diff = {
        keep_terminal_focus = false,
      },
    },
    keys = {
      { "<leader>ac", "<cmd>ClaudeCode<cr>",          desc = "Toggle Claude" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>",     desc = "Focus Claude" },
      { "<leader>as", "<cmd>ClaudeCodeAdd<cr>",        desc = "Add to context", mode = { "n", "v" } },
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>",   desc = "Deny diff" },
    },
  },
}
```

- [ ] **Step 3: Verify headless startup is clean**

```bash
nvim --headless "+Lazy! install" +qa 2>&1 | grep -iE "error|ERROR" | grep -v "^$"
```

Expected: no output (no errors during plugin install)

Then:

```bash
nvim --headless +qa 2>&1 | grep -iE "error|ERROR" | grep -v "^$"
```

Expected: no output

---

### Task 2: Add which-key group for `<leader>a`

**Files:**
- Modify: `~/.config/nvim/lua/plugins/whichkey.lua`

- [ ] **Step 1: Read the current which-key spec**

Open `~/.config/nvim/lua/plugins/whichkey.lua` and locate the `wk.add({...})` block. It currently contains:

```lua
wk.add({
  { "<leader>f",  group = "Find (Telescope)" },
  { "<leader>g",  group = "Git" },
  { "<leader>c",  group = "Code (LSP)" },
  { "<leader>d",  group = "Debug (DAP)" },
  { "<leader>s",  group = "Show (Diagnostics)" },
  { "<leader>b",  group = "Buffer" },
})
```

- [ ] **Step 2: Add the AI group**

Append `{ "<leader>a", group = "AI (Claude)" },` as the last entry inside `wk.add({...})`:

```lua
wk.add({
  { "<leader>f",  group = "Find (Telescope)" },
  { "<leader>g",  group = "Git" },
  { "<leader>c",  group = "Code (LSP)" },
  { "<leader>d",  group = "Debug (DAP)" },
  { "<leader>s",  group = "Show (Diagnostics)" },
  { "<leader>b",  group = "Buffer" },
  { "<leader>a",  group = "AI (Claude)" },
})
```

- [ ] **Step 3: Verify headless startup is still clean**

```bash
nvim --headless +qa 2>&1 | grep -iE "error|ERROR" | grep -v "^$"
```

Expected: no output

---

### Task 3: Commit

**Files:**
- `~/.config/nvim/lua/plugins/claudecode.lua`
- `~/.config/nvim/lua/plugins/whichkey.lua`

- [ ] **Step 1: Stage and commit**

```bash
cd ~/.config/nvim
git add lua/plugins/claudecode.lua lua/plugins/whichkey.lua
git commit -m "feat: add claudecode.nvim with snacks floating terminal"
```

Expected: commit succeeds, showing 2 files changed.

---

## Verification (manual, after commit)

Open Neovim without a file argument:

```bash
nvim
```

1. Press `<Space>` and confirm `a` appears in the which-key popup as "AI (Claude)"
2. Press `<Space>ac` — a right-side panel should open running the `claude` CLI
3. The CLI should connect automatically (MCP server was already running since startup)
4. Open any source file, make a visual selection, press `<Space>as` — the file/selection should be added to Claude's context
5. Ask Claude to make a change — confirm a diff split appears in Neovim
6. Press `<Space>aa` to accept — verify focus returns to the code buffer
