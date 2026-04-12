-- ~/.config/nvim/lua/plugins/extras.lua
return {
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("Comment").setup()
    end,
  },
  -- Shared UI component used by neo-tree and others
  { "MunifTanjim/nui.nvim", lazy = true },
  -- Dev icons used by lualine, bufferline, neo-tree, telescope
  { "nvim-tree/nvim-web-devicons", lazy = true },
  -- Async library used by telescope, neo-tree, lazygit
  { "nvim-lua/plenary.nvim", lazy = true },
}
