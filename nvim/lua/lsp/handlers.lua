-- ~/.config/nvim/lua/lsp/handlers.lua
local M = {}

M.on_attach = function(_, bufnr)
  local map = function(keys, func, desc)
    vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
  end

  map("gd", vim.lsp.buf.definition, "Go to Definition")
  map("gD", vim.lsp.buf.declaration, "Go to Declaration")
  map("gr", vim.lsp.buf.references, "Go to References")
  map("gi", vim.lsp.buf.implementation, "Go to Implementation")
  map("K", vim.lsp.buf.hover, "Hover Documentation")
  map("<leader>k", vim.lsp.buf.signature_help, "Signature Help")
  map("<leader>rn", vim.lsp.buf.rename, "Rename Symbol")
  map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
  map("[d", vim.diagnostic.goto_prev, "Previous Diagnostic")
  map("]d", vim.diagnostic.goto_next, "Next Diagnostic")
  map("<leader>d", vim.diagnostic.open_float, "Show Diagnostic")
  map("<leader>q", vim.diagnostic.setloclist, "Diagnostic List")
end

M.capabilities = require("cmp_nvim_lsp").default_capabilities()

return M
