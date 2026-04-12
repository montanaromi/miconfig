-- ~/.config/nvim/lua/plugins/telescope.lua
return {
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",  -- Pin for Neovim 0.10; latest requires 0.11+
    cmd = "Telescope",
    keys = {
      { "<leader>ff" },
      { "<leader>fg" },
      { "<leader>fb" },
      { "<leader>fh" },
      { "<leader>fd" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable("make") == 1
        end,
      },
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")

      telescope.setup({
        defaults = {
          mappings = {
            i = {
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-j>"] = actions.move_selection_next,
              ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
            },
          },
          file_ignore_patterns = { "node_modules", ".git/", "dist/" },
          path_display = { "truncate" },
        },
      })

      pcall(telescope.load_extension, "fzf")
    end,
  },
}
