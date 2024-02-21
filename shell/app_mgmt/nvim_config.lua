-- NeoVim Configution File
-- LINUX: ~/.config/nvim/init.lua
-- WINDOWS: ~/AppData/Local/nvim/init.lua

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
require("lazy").setup({
	-- Telescope
	{'nvim-telescope/telescope.nvim', branch = '0.1.x', dependencies = { 'nvim-lua/plenary.nvim' }},
	-- Treesitter
	{ "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
	-- Tokyonight Theme
	{ "folke/tokyonight.nvim", lazy = false, priority = 1000, opts = {} },
	-- Lualine
	{ 'nvim-lualine/lualine.nvim', dependencies = { 'nvim-tree/nvim-web-devicons' } },
	-- Indent-Blanckline
	{ "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },
	-- Hop
	{ 'smoka7/hop.nvim' },
})

--[[
nvim-treesitter
---------------
https://github.com/nvim-treesitter/nvim-treesitter
Commands
	Install language	: TSInstall <language_to_install>
	Update				: TSUpdate | TSUpdate all
	Installation Status	: TSInstallInfo
--]]
require("nvim-treesitter.configs").setup {
	ensure_installed = { "bash", "c", "cpp", "css", "diff", "dockerfile", "dot", "go", "gosum", "gowork", "gpg", "graphql", "html", "javascript", "json", "jsonc", "lua", "make", "markdown", "passwd", "pem", "printf", "proto", "python", "scss", "sql", "templ", "terraform", "toml", "tsx", "typescript", "xml", "yaml" },
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

--[[
telescope.nvim
--------------
https://github.com/nvim-telescope/telescope.nvim
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
local function current_cursor_hex()
	local cursor = vim.fn.getcurpos()
	local line = vim.fn.getline('.')
	local character = string.sub(line, cursor[3], cursor[3])
	if character == "" then
		return '0x00'
	end
	local ascii_value = string.byte(character)
	return string.format('0x%02X', ascii_value)
end

require('lualine').setup {
	options = {
		theme = 'tokyonight'
	},
	sections = {
		lualine_a = {'mode'},
		lualine_b = {'branch', 'diff', 'diagnostics'},
		lualine_c = {{ 'filename', file_status = true, path = 1 }},
		lualine_x = {'encoding', 'fileformat', 'filetype'},
		lualine_y = {current_cursor_hex, 'progress'},
		lualine_z = {'location'}
	  },
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = {'filename'},
		lualine_x = {'location'},
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

vim.cmd[[colorscheme tokyonight]]

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
-- Open/Close (toggle) Netrw in the initial directory when in normal mode
vim.keymap.set('n', '<leader>dd', ':Lexplore<cr>')

-- telescope.nvim
local builtin = require('telescope.builtin')
-- Fuzzy find files with 'ff' in normal mode
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
-- Fuzzy live grep files with 'fg' in normal mode
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
-- Fuzzy find buffers with 'fb' in normal mode
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
-- Show help with 'fh' in normal mode
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

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
