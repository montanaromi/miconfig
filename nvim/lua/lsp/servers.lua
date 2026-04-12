-- ~/.config/nvim/lua/lsp/servers.lua
return {
  pyright = {},

  rust_analyzer = {
    settings = {
      ["rust-analyzer"] = {
        check = { command = "clippy" },
      },
    },
  },

  gopls = {
    settings = {
      gopls = {
        analyses = { unusedparams = true },
        staticcheck = true,
      },
    },
  },

  ts_ls = {},

  lua_ls = {
    settings = {
      Lua = {
        diagnostics = { globals = { "vim" } },
        workspace = {
          library = vim.api.nvim_get_runtime_file("lua", true),
          checkThirdParty = false,
        },
        telemetry = { enable = false },
      },
    },
  },

  clangd = {
    cmd = {
      "clangd",
      "--background-index",
      "--clang-tidy",
      "--header-insertion=iwyu",
    },
  },
}
