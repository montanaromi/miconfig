-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Core settings (must come before lazy so leader is set before any plugin maps it)
require("core.options")
require("core.keymaps")

-- Load plugins (lazy auto-discovers lua/plugins/*.lua)
require("lazy").setup("plugins", {
  change_detection = { notify = false },
})
