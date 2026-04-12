-- ~/.config/nvim/lua/plugins/lsp.lua
return {
  {
    "neovim/nvim-lspconfig",
    -- Pin to last commit before deprecation of Neovim 0.10 support (v3.0.0 drops it)
    -- Remove this tag once Neovim is upgraded to 0.11+
    tag = "v2.1.0",
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
