-- ~/.config/nvim/lua/plugins/filetree.lua
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    keys = { { "<leader>e", "<Cmd>Neotree toggle<CR>", desc = "Toggle file tree" } },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("neo-tree").setup({
        close_if_last_window = true,
        window = { width = 30 },
        filesystem = {
          follow_current_file = { enabled = true },
          filtered_items = {
            hide_dotfiles = false,
            hide_gitignored = false,
            hide_by_name = { ".DS_Store", "thumbs.db" },
          },
        },
        buffers = {
          follow_current_file = { enabled = true },
        },
        git_status = {
          window = { position = "float" },
        },
      })
    end,
  },
}
