-- ~/.config/nvim/lua/plugins/whichkey.lua
return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      local wk = require("which-key")
      wk.setup({
        window = { border = "rounded" },
      })

      wk.add({
        { "<leader>f",  group = "Find (Telescope)" },
        { "<leader>g",  group = "Git" },
        { "<leader>c",  group = "Code (LSP)" },
        { "<leader>d",  group = "Debug / Diagnostics" },
        { "<leader>b",  group = "Buffer" },
      })
    end,
  },
}
