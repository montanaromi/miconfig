-- ~/.config/nvim/lua/plugins/treesitter.lua
return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      -- nvim-treesitter v1: 'configs' module removed; use new API
      require("nvim-treesitter").setup()

      -- Install parsers for configured languages
      require("nvim-treesitter").install({
        "lua", "python", "rust", "go", "typescript", "javascript",
        "c", "cpp", "vim", "vimdoc", "query", "bash", "json", "yaml",
        "toml", "markdown", "html", "css",
      })

      -- Enable treesitter highlighting + indentation per buffer
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          local ok = pcall(vim.treesitter.start, ev.buf)
          if ok then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
