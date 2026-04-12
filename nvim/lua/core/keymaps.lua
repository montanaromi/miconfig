-- ~/.config/nvim/lua/core/keymaps.lua
vim.g.mapleader = " "
vim.g.maplocalleader = ","

local map = vim.keymap.set

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Buffer navigation
map("n", "<S-l>", ":bnext<CR>", { desc = "Next buffer" })
map("n", "<S-h>", ":bprevious<CR>", { desc = "Previous buffer" })
map("n", "<leader>bd", ":bdelete<CR>", { desc = "Delete buffer" })

-- Clear search highlight
map("n", "<leader>h", ":nohlsearch<CR>", { desc = "Clear search highlight" })

-- File tree
map("n", "<leader>e", ":Neotree toggle<CR>", { desc = "Toggle file tree" })

-- Telescope
map("n", "<leader>ff", ":Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>fg", ":Telescope live_grep<CR>", { desc = "Live grep" })
map("n", "<leader>fb", ":Telescope buffers<CR>", { desc = "Find buffers" })
map("n", "<leader>fh", ":Telescope help_tags<CR>", { desc = "Help tags" })
map("n", "<leader>fd", ":Telescope diagnostics<CR>", { desc = "Diagnostics" })

-- Lazygit
map("n", "<leader>gg", ":LazyGit<CR>", { desc = "Open LazyGit" })

-- DAP
map("n", "<F5>",  function() require("dap").continue() end,           { desc = "DAP: Continue" })
map("n", "<F10>", function() require("dap").step_over() end,          { desc = "DAP: Step over" })
map("n", "<F11>", function() require("dap").step_into() end,          { desc = "DAP: Step into" })
map("n", "<F12>", function() require("dap").step_out() end,           { desc = "DAP: Step out" })
map("n", "<leader>db", function() require("dap").toggle_breakpoint() end, { desc = "DAP: Toggle breakpoint" })

-- Better indenting in visual mode
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Move lines up/down
map("n", "<A-j>", ":m .+1<CR>==", { desc = "Move line down" })
map("n", "<A-k>", ":m .-2<CR>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
