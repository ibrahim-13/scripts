-- NeoVim Configution File
-- LINUX: ~/.config/nvim/init.lua
-- WINDOWS: ~/AppData/Local/nvim/init.lua

-----------
-- Utils --
-----------

local function tableMerge(source, target)
	for _, v in ipairs(source) do
		table.insert(target, v)
	end
end

local function check_if_minimal_conf()
	local name = vim.fn.stdpath('config') .. '/minimal'
	local f = io.open(name, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

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

--[[
lazy.nvim
---------
https://github.com/folke/lazy.nvim
--]]
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
local isMinimal = check_if_minimal_conf()
local plugins_default = {
	-- Telescope
	{ 'nvim-telescope/telescope.nvim',       branch = '0.1.x',                                dependencies = { 'nvim-lua/plenary.nvim' } },
	-- Tokyonight Theme
	{ "folke/tokyonight.nvim",               lazy = false,                                    priority = 1000,                           opts = {} },
	-- Lualine
	{ 'nvim-lualine/lualine.nvim',           dependencies = { 'nvim-tree/nvim-web-devicons' } },
	-- Indent-Blanckline
	{ "lukas-reineke/indent-blankline.nvim", main = "ibl",                                    opts = {} },
	-- Hop
	{ 'smoka7/hop.nvim' },
	-- Comment
	{ 'numToStr/Comment.nvim',               opts = {},                                       lazy = false, },
}

local plugins_extended = {
	-- lsp-zero
	{ 'williamboman/mason.nvim' },
	{ 'williamboman/mason-lspconfig.nvim' },
	{ 'VonHeikemen/lsp-zero.nvim',        branch = 'v3.x' },
	{ 'neovim/nvim-lspconfig' },
	{ 'hrsh7th/cmp-nvim-lsp' },
	{ 'hrsh7th/nvim-cmp' },
	{ 'L3MON4D3/LuaSnip' },
	-- Treesitter
	{ "nvim-treesitter/nvim-treesitter",  build = ":TSUpdate" },
}

local plugins = {}
tableMerge(plugins_default, plugins)

if not isMinimal then
	tableMerge(plugins_extended, plugins)
end

require("lazy").setup(plugins)

if not isMinimal then
	--[[
	lsp-zero
	--------
	https://github.com/VonHeikemen/lsp-zero.nvim
	--]]
	local lsp_zero = require('lsp-zero')

	lsp_zero.on_attach(function(client, bufnr)
		-- see :help lsp-zero-keybindings
		-- to learn the available actions
		lsp_zero.default_keymaps({ buffer = bufnr })
	end)

	-- to learn how to use mason.nvim with lsp-zero
	-- read this: https://github.com/VonHeikemen/lsp-zero.nvim/blob/v3.x/doc/md/guides/integrate-with-mason-nvim.md
	require('mason').setup({})
	require('mason-lspconfig').setup({
		ensure_installed = {},
		handlers = {
			lsp_zero.default_setup,
		},
	})

	-- Run command :Mason to manage packages
	-- Commands are prefixed with Mason, they can be cycled by typing :Maosn and then TAB
	require('mason').setup({})
	require('mason-lspconfig').setup({
		ensure_installed = { 'lua_ls', 'bashls', 'cssls', 'cssmodules_ls', 'dockerls', 'docker_compose_language_service', 'eslint', 'gopls', 'jsonls', 'tsserver', 'sqls', 'yamlls' },
		handlers = {
			lsp_zero.default_setup,
		},
	})

	--[[
	nvim-treesitter
	---------------
	https://github.com/nvim-treesitter/nvim-treesitter
	Commands
		Install language	: TSInstall <language_to_install>
		Update				: TSUpdate | TSUpdate all
		Installation Status	: TSInstallInfo
	Commands are prefixed with TS, they can by cycled by typing :TS and then TAB
	--]]
	require("nvim-treesitter.configs").setup {
		ensure_installed = { "bash", "c", "cpp", "css", "diff", "dockerfile", "dot", "go", "gosum", "gowork", "gpg", "graphql", "html", "ini", "javascript", "json", "jsonc", "lua", "make", "markdown", "passwd", "pem", "printf", "proto", "python", "scss", "sql", "templ", "terraform", "toml", "tsx", "typescript", "xml", "yaml" },
		sync_install = false,
		auto_install = true,
		-- ignore_install = { "javascript" },
		highlight = {
			enable = true,
			-- disable = { "javascript" },
			--[[
		disable = function(lang, bug)
			local max_filesize = 100 * 1024 -- 100 KB
			local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
			if ok and stats and stats.size > max_filesize then
				return true
			end
		end
		--]]
			additional_vim_regex_highlighting = false,
		}
	}
end

--[[
telescope.nvim
--------------
https://github.com/nvim-telescope/telescope.nvim

NOTE: If file searches does not respects .gitignore, then check if `ripgrep` is installed
	or run health check command
Commands:
	:checkhealth telescope
Default Mappings:
	<C-n>/<Down>	Next item
	<C-p>/<Up>	Previous item
	j/k	Next/previous (in normal mode)
	H/M/L	Select High/Middle/Low (in normal mode)
	gg/G	Select the first/last item (in normal mode)
	<CR>	Confirm selection
	<C-x>	Go to file selection as a split
	<C-v>	Go to file selection as a vsplit
	<C-t>	Go to a file in a new tab
	<C-u>	Scroll up in preview window
	<C-d>	Scroll down in preview window
	<C-f>	Scroll left in preview window
	<C-k>	Scroll right in preview window
	<M-f>	Scroll left in results window
	<M-k>	Scroll right in results window
	<C-/>	Show mappings for picker actions (insert mode)
	?	Show mappings for picker actions (normal mode)
	<C-c>	Close telescope (insert mode)
	<Esc>	Close telescope (in normal mode)
	<Tab>	Toggle selection and move to next selection
	<S-Tab>	Toggle selection and move to prev selection
	<C-q>	Send all items not filtered to quickfixlist (qflist)
	<M-q>	Send all selected items to qflist
	<C-r><C-w>	Insert cword in original window into prompt (insert mode)
--]]
require("telescope").setup({
	defaults = {
		layout_config = {
			horizontal = {
				width = function(_, max_columns, _)
					return max_columns
				end,
				height = function(_, _, max_lines)
					return max_lines
				end,
			},
		},
	},
})

--[[
lualine
-------
https://github.com/nvim-lualine/lualine.nvim
--]]

require('lualine').setup {
	options = {
		theme = 'tokyonight'
	},
	sections = {
		lualine_a = { 'mode' },
		lualine_b = { 'branch', 'diff' },
		lualine_c = { { 'filename', file_status = true, path = 1 } },
		lualine_x = { 'encoding', 'fileformat', 'filetype' },
		lualine_y = { 'diagnostics', 'progress' },
		lualine_z = { 'location' }
	},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = { 'filename' },
		lualine_x = { 'location' },
		lualine_y = {},
		lualine_z = {}
	},
}

--[[
indent-blankline.nvim
---------------------
https://github.com/lukas-reineke/indent-blankline.nvim
--]]
require("ibl").setup()

--[[
hop.nvim
--------
https://github.com/smoka7/hop.nvim
Commands:
	:checkhealth hop
--]]

local hop = require('hop')
hop.setup {
	-- Press 'space' to quit finding
	quit_key = '<SPC>'
}

--[[
tokyonight.nvim
https://github.com/folke/tokyonight.nvim
--]]
require("tokyonight").setup({
	style = "night",
	on_colors = function(colors)
		colors.bg = "#000000"
		colors.comment = colors.dark5
	end
})

vim.cmd [[colorscheme tokyonight]]

--[[
Comment.nvim
https://github.com/numToStr/Comment.nvim
--]]
require('Comment').setup({
	---Add a space b/w comment and the line
	padding = true,
	---Whether the cursor should stay at its position
	sticky = true,
	---Lines to be ignored while (un)comment
	ignore = nil,
	---LHS of toggle mappings in NORMAL mode
	toggler = {
		---Line-comment toggle keymap
		line = 'gcc',
		---Block-comment toggle keymap
		block = 'gbc',
	},
	---LHS of operator-pending mappings in NORMAL and VISUAL mode
	opleader = {
		---Line-comment keymap
		line = 'gc',
		---Block-comment keymap
		block = 'gb',
	},
	---LHS of extra mappings
	extra = {
		---Add comment on the line above
		-- above = 'gcO',
		---Add comment on the line below
		-- below = 'gco',
		---Add comment at the end of line
		-- eol = 'gcA',
	},
	---Enable keybindings
	---NOTE: If given `false` then the plugin won't create any mappings
	mappings = {
		---Operator-pending mapping; `gcc` `gbc` `gc[count]{motion}` `gb[count]{motion}`
		basic = true,
		---Extra mapping; `gco`, `gcO`, `gcA`
		extra = false,
	},
	---Function to call before (un)comment
	pre_hook = nil,
	---Function to call after (un)comment
	post_hook = nil,
})

--[[
===========
Keybindings
===========
--]]

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
vim.keymap.set('n', '<LEADER>w', '<CMD>write<CR>', { desc = 'Save' })
-- Copy to clipboard with 'gy' in normal+visual mode
vim.keymap.set({ 'n', 'x' }, 'gy', '"+y')
-- Paste to clipboard with 'gp' in normal+visual mode
vim.keymap.set({ 'n', 'x' }, 'gp', '"+p')
-- While deleting in normal+visual mode, deleting with 'x' and 'X' with not change registers
vim.keymap.set({ 'n', 'x' }, 'x', '"_x')
vim.keymap.set({ 'n', 'x' }, 'X', '"_d')
-- Select all with 'space+a' in normal mode
vim.keymap.set('n', '<LEADER>a', ':keepjumps normal! ggVG<CR>')
-- Open Netrw in the current directory of the file (buffer) when in normal mode
vim.keymap.set('n', '<LEADER>df', ':Lexplore %:p:h<CR>')
-- Open/Close (toggle) Netrw in the initial directory when in normal mode
vim.keymap.set('n', '<LEADER>dd', ':Lexplore<CR>')
-- Scroll up 7 lines with ctrl+k when in normal+visual mode
vim.keymap.set({ 'n', 'x' }, '<C-k>', '7<C-y>')
-- Scroll down 7 lines with ctrl+j when in normal+visual mode
vim.keymap.set({ 'n', 'x' }, '<C-j>', '7<C-e>')
-- Cursor up with ctrl+k when in input mode
vim.keymap.set('i', '<C-k>', '<Up>')
-- Cursor down with ctrl+j when in input mode
vim.keymap.set('i', '<C-j>', '<Down>')
-- Cursor left with ctrl+k when in input mode
vim.keymap.set('i', '<C-h>', '<Left>')
-- Cursor right with ctrl+j when in input mode
vim.keymap.set('i', '<C-l>', '<Right>')
-- Wrap selection with double quote "" when in visual mode
vim.keymap.set('x', '<LEADER>"', 'c"<C-r>""<ESC>')
-- Wrap selection with single quote '' when in visual mode
vim.keymap.set('x', '<LEADER>\'', 'c\'<C-r>"\'<ESC>')

-- telescope.nvim
local builtin = require('telescope.builtin')
-- Fuzzy find files with 'ff' in normal mode
vim.keymap.set('n', '<LEADER>ff', builtin.find_files, {})
-- Fuzzy live grep files with 'fg' in normal mode
vim.keymap.set('n', '<LEADER>fg', builtin.live_grep, {})
-- Fuzzy find buffers with 'fb' in normal mode
vim.keymap.set('n', '<LEADER>fb', builtin.buffers, {})
-- Show help with 'fh' in normal mode
vim.keymap.set('n', '<LEADER>fh', builtin.help_tags, {})
-- List built-in pickers and run them on <CR>
vim.keymap.set('n', '<LEADER>pp', builtin.builtin, {})

-- Tabs can be traversed with 'gt' and 'gT', thus the followin
-- bindings were also added with 'g' prefix
-- https://neovim.io/doc/user/tabpage.html

-- Create the current buffer in new tab with 'gn' in normal mode
vim.keymap.set('n', 'gn', ':tab split<CR>')
-- Close the current tab with 'gc' in normal mode
vim.keymap.set('n', 'gc', ':tabc<CR>')

--[[
Custom Commands
--]]
local function CmdShowLspLog()
	local logfile = require('vim.lsp.log').get_filename()
	vim.cmd(([[tabnew %s]]):format(logfile))
end
-- Type :CmdShowLspLog to open the lsp.log file
vim.api.nvim_create_user_command("CmdShowLspLog", CmdShowLspLog, {
	desc = "Opens the lsp log.",
})

-- hop.nvim
-- Find with 1 char with 'f' in the visible buffer
vim.keymap.set('',
	'f', function()
		hop.hint_char1({ direction = nil, current_line_only = false })
	end,
	{ remap = true })
-- Find with 2 chars with 'F' in the visible buffer
vim.keymap.set('',
	'F',
	function()
		hop.hint_char2({ direction = nil, current_line_only = false })
	end,
	{ remap = true })
-- Find the input pattern with 't' in the visible buffer
vim.keymap.set('',
	't', function()
		hop.hint_patterns({ direction = nil, current_line_only = false })
	end,
	{ remap = true })

vim.keymap.set('',
	'T', function()
		hop.hint_words({ direction = nil, current_line_only = false })
	end,
	{ remap = true })

--[[
-- Handing binary files:
------------------------
-- Open file in binary mode so that NVIM does not apply any special modification
-- nvim -b file.bin
--
-- Show hex
-- :%!xxd
--
-- Update the hex part of the output and write (modification other then hex parts are ignored, only replace with 'r' or 'R'
-- :%!xxd -r
--
-- Highlight
-- :set ft=xxd
--
-- See unprintable characters in hex
-- :set display=uhex
--
-- View hex code of character under cursor
-- ga
--
-- File Formats
---------------
-- Formats: unix (<NL>), dos (<CR><NL>), mac (<CR>)
--
-- Convert file format
-- :set fileformat=unix
-- :write
--
-- VIM motions
--------------
-- https://neovim.io/doc/user/motion.html
--
-- Get LSP logs location
------------------------
-- :lua =require('vim.lsp.log').get_filename()
-- Set log level in init.lua
-- vim.lsp.set_log_level('debug')
--
-- View log messages
--------------------
-- :messages
--]]
