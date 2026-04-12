-- ~/.config/nvim/lua/lsp/init.lua
local handlers = require("lsp.handlers")
local servers = require("lsp.servers")

require("mason").setup({
  ui = {
    icons = {
      package_installed = "✓",
      package_pending = "➜",
      package_uninstalled = "✗",
    },
  },
})

require("mason-lspconfig").setup({
  ensure_installed = vim.tbl_keys(servers),
  automatic_installation = true,
})

-- Diagnostic display
vim.diagnostic.config({
  virtual_text = { prefix = "●" },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = "always",
  },
})

-- Global floating-window border (replaces vim.lsp.with, Neovim 0.11+)
vim.o.winborder = "rounded"

-- Global LSP defaults applied to every server
vim.lsp.config("*", {
  on_attach = handlers.on_attach,
  capabilities = handlers.capabilities,
})

-- Per-server overrides
for server, config in pairs(servers) do
  if next(config) ~= nil then
    vim.lsp.config(server, config)
  end
end

-- Enable all configured servers
vim.lsp.enable(vim.tbl_keys(servers))
