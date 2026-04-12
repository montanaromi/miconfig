-- ~/.config/nvim/lua/plugins/ui.lua
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        integrations = {
          neotree = true,
          telescope = true,
          treesitter = true,
          bufferline = true,
          gitsigns = true,
          which_key = true,
          dap = true,
          dap_ui = true,
        },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons", "catppuccin/nvim" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "catppuccin-mocha",
          globalstatus = true,
        },
        sections = {
          lualine_x = { "encoding", "fileformat", "filetype" },
        },
      })
    end,
  },
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({
        options = {
          diagnostics = "nvim_lsp",
          offsets = {
            { filetype = "neo-tree", text = "File Explorer", highlight = "Directory" },
          },
        },
      })
    end,
  },
}
