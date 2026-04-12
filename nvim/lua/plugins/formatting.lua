-- ~/.config/nvim/lua/plugins/formatting.lua
return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          python          = { "black" },
          rust            = { "rustfmt" },
          go              = { "gofmt" },
          typescript      = { "prettier" },
          javascript      = { "prettier" },
          typescriptreact = { "prettier" },
          javascriptreact = { "prettier" },
          lua             = { "stylua" },
          c               = { "clang_format" },
          cpp             = { "clang_format" },
          json            = { "prettier" },
          yaml            = { "prettier" },
          markdown        = { "prettier" },
        },
        format_on_save = {
          timeout_ms = 500,
          lsp_fallback = true,
        },
        notify_on_error = true,
      })

      vim.keymap.set({ "n", "v" }, "<leader>cf", function()
        require("conform").format({ async = true, lsp_fallback = true })
      end, { desc = "Format file" })
    end,
  },
}
