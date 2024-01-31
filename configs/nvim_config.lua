-- NeoVim Configution File
-- ~/.config/nvim/init.lua

--
-- Options
--

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

--
-- Keybindings
--

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
vim.keymap.set('n', '<leader>df', ':Lexplore %:p:h<cr>')
-- Open Netrw in the initial directory when in normal mode
vim.keymap.set('n', '<leader>dd', ':Lexplore<cr>')
