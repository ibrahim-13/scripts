-- NeoVim Configution File
-- ~/.config/nvim/init.lua

-------------
-- Options --
-------------

-- Show line number
vim.opt.number = true

-- Mouse interactions
vim.opt.mouse = 'a'

-- Ignore case when searching
vim.opt.ignorecase = true
-- Don't ignore case if keyword starts with uppercase
vim.opt.smartcase = true
-- Disable search highlight
vim.opt.hlsearch = false

-- Enalbe line wrap
vim.opt.wrap = true
-- Perserve indentation of a virtual line - ex. wraped lines
vim.opt.breakindent = true

-- Amount of space on screen a TAB character occupy
vim.opt.tabstop = 4
-- Amount of space for indentation with >> and <<
vim.opt.shiftwidth = 4
-- Convert TAB to SPACE
vim.opt.expandtab = false

-----------------
-- Keybindings --
-----------------

--[[
vim.keymap.set({mode}, {lhs}, {rhs}, {opts})

Modes:
n	: Normal mode
i	: Insert mode
x	: Visual mode
s	: Selection mode
v	: Visual + Selection
t	: Terminal mode
o	: Operator-pending
''	: Equivalent of h + v + o

{lhs}	: Key to bind
{rhs}	: Action to execute, string command or Lua function
--]]

-- Set <leader> to space
vim.g.mapleader = ' '
-- Write with 'space+w' in normal mode
vim.keymap.set('n', '<leader>w', '<cmd>write<cr>', { desc = 'Save' })
-- Copy to clipboard with 'gy' in normal+visual mode
vim.keymap.set({'n', 'x'}, 'gy', '"+y')
-- Paste to clipboard with 'gp' in normal+visual mode
vim.keymap.set({'n', 'x'}, 'gp', '"+p')
-- While deleting in normal+visual mode, deleting with 'x' and 'X' with not change registers
vim.keymap.set({'n', 'x'}, 'x', '"_x')
vim.keymap.set({'n', 'x'}, 'X', '"_d')
-- Select all with 'space+a' in normal mode
vim.keymap.set('n', '<leader>a', ':keepjumps normal! ggVG<cr>')
-- Open Netrw in the current directory of the file (buffer) when in normal mode

----------------------------
-- lazy.nvim Installation --
----------------------------
-- https://github.com/folke/lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
-- Setup plug-ins
require("lazy").setup({
	-- https://github.com/nvim-telescope/telescope.nvim
	{'nvim-telescope/telescope.nvim', branch = '0.1.x', dependencies = { 'nvim-lua/plenary.nvim' }}
	-- https://github.com/nvim-treesitter/nvim-treesitter
})

-- telescope config
--
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})