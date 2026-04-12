-- ~/.config/nvim/lua/lsp/init.lua
local mason = require("mason")
local mason_lspconfig = require("mason-lspconfig")
local lspconfig = require("lspconfig")
local handlers = require("lsp.handlers")
local servers = require("lsp.servers")

mason.setup({
  ui = {
    icons = {
      package_installed = "✓",
      package_pending = "➜",
      package_uninstalled = "✗",
    },
  },
})

mason_lspconfig.setup({
  ensure_installed = vim.tbl_keys(servers),
  automatic_installation = true,
  -- automatic_enable requires vim.lsp.enable() which is Neovim 0.11+; disable on 0.10
  automatic_enable = false,
})

-- Diagnostic display config
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

-- Rounded borders for hover and signature help
vim.lsp.handlers["textDocument/hover"] =
  vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
vim.lsp.handlers["textDocument/signatureHelp"] =
  vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

-- Wire each server (shallow-copy to avoid mutating the cached servers module)
for server, config in pairs(servers) do
  local merged = vim.tbl_extend("force", config, {
    on_attach = handlers.on_attach,
    capabilities = handlers.capabilities,
  })
  lspconfig[server].setup(merged)
end
