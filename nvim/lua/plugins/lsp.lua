-- ~/.config/nvim/lua/plugins/lsp.lua
return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      -- cmp-nvim-lsp must be available before handlers.lua calls default_capabilities()
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      require("lsp")
    end,
  },
}
