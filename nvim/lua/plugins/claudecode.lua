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
