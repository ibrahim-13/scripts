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

local function check_if_dir(dir)
	if vim.fn.isdirectory(dir) then
		return true
	else
		return false
	end
end

local function check_if_exec_exists(exec, msg)
	if vim.fn.executable(exec) ~= 1 then
		print(msg)
	end
end

-- Show a string in a read-only scratch buffer, opened in a vertical split.
-- Press 'q' in the preview to close it.
local function open_string_readonly(content, title)
	local name = title or "Read-Only Preview"

	-- Buffer names have to be unique, so wipe a leftover preview of the same
	-- name before creating a new one (otherwise set_name fails with E95)
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[b].buftype == "nofile"
			and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":t") == name then
			pcall(vim.api.nvim_buf_delete, b, { force = true })
		end
	end

	-- Unlisted scratch buffer
	local buf = vim.api.nvim_create_buf(false, true)

	-- Fill the buffer BEFORE locking it down, a non-modifiable buffer
	-- rejects nvim_buf_set_lines
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content or "", "\n", { plain = true }))

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.bo[buf].readonly = true
	vim.api.nvim_buf_set_name(buf, name)

	-- Show it in a vertical split
	vim.cmd("vsplit")
	vim.api.nvim_win_set_buf(0, buf)
	-- Window-local tweaks, spell check is on globally and is noise here
	vim.wo.spell = false
	vim.wo.number = false

	vim.keymap.set('n', 'q', '<CMD>close<CR>', { buffer = buf, nowait = true, silent = true })
end

-- Text shown by the :CustomInfo command
local custom_info_text = [[
Custom Info
===========

This text lives in `custom_info_text` in init.lua, edit it to show
whatever information should be at hand.

Press 'q' to close this window.]]

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

-- Enable line wrap
vim.opt.wrap = true
-- Preserve indentation of a virtual line - ex. wrap lines
vim.opt.breakindent = true
vim.opt.breakindentopt = "shift:2,min:40,sbr"

-- Amount of space on screen a TAB character occupy
vim.opt.tabstop = 4
-- Amount of space for indentation with >> and <<
vim.opt.shiftwidth = 4
-- Convert TAB to SPACE
vim.opt.expandtab = true  -- Convert tabs to spaces when pressing Tab
vim.opt.tabstop = 4       -- Number of spaces a tab represents
vim.opt.shiftwidth = 4    -- Number of spaces for each indentation level
vim.opt.softtabstop = 4   -- Number of spaces a tab counts for in insert mode
vim.opt.textwidth = 0			-- Hard wrap text width limit (0 = no hard wrap)
-- Enable spell check: https://neovim.io/doc/user/spell.html
vim.opt.spell = true

-- update docs
local dir_doc = vim.fn.stdpath("config") .. "/doc"
if check_if_dir(dir_doc) then
	vim.cmd(([[helptags %s]]):format(dir_doc))
else
	print("could not find documentation directory")
end

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
	{ 'nvim-telescope/telescope.nvim',				version = '*',                                   dependencies = { 'nvim-lua/plenary.nvim' } },
	-- Tokyonight Theme
	{ "folke/tokyonight.nvim",								lazy = false,                                    priority = 1000,                           opts = {} },
	-- Lualine
	{ 'nvim-lualine/lualine.nvim',						dependencies = { 'nvim-tree/nvim-web-devicons' } },
	-- Indent-Blankline
	{ "lukas-reineke/indent-blankline.nvim",	main = "ibl",                                    opts = {} },
	-- Hop
	{ 'smoka7/hop.nvim',											version = "*" },
	-- NvimTree
	{ "nvim-tree/nvim-tree.lua",          		version = "*",      lazy = false, dependencies = { "nvim-tree/nvim-web-devicons" } },
	-- codediff.nvim
	{ "esmuellert/codediff.nvim", cmd = "CodeDiff" }
}

local plugins_extended = {
    -- Mason for managing LSP
	-- https://github.com/mason-org/mason.nvim
	-- https://github.com/mason-org/mason-lspconfig.nvim
	-- https://github.com/neovim/nvim-lspconfig
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {},
        dependencies = {
            { "mason-org/mason.nvim", opts = {} },
            "neovim/nvim-lspconfig",
        },
    },
    -- blick.cmp completion
	-- https://github.com/saghen/blink.cmp
    {
      'saghen/blink.cmp',
      -- optional: provides snippets for the snippet source
      -- dependencies = { 'rafamadriz/friendly-snippets' },

      -- use a release tag to download pre-built binaries
      version = '1.*',

      ---@module 'blink.cmp'
      ---@type blink.cmp.Config
      opts = {
        -- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
        -- 'super-tab' for mappings similar to vscode (tab to accept)
        -- 'enter' for enter to accept
        -- 'none' for no mappings
        --
        -- All presets have the following mappings:
        -- C-space: Open menu or open docs if already open
        -- C-n/C-p or Up/Down: Select next/previous item
        -- C-e: Hide menu
        -- C-k: Toggle signature help (if signature.enabled = true)
        --
        -- See :h blink-cmp-config-keymap for defining your own keymap
        keymap = { preset = 'default' },

        appearance = {
          -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
          -- Adjusts spacing to ensure icons are aligned
          nerd_font_variant = 'mono'
        },

        -- (Default) Only show the documentation popup when manually triggered
        completion = { documentation = { auto_show = false } },

        -- Default list of enabled providers defined so that you can extend it
        -- elsewhere in your config, without redefining it, due to `opts_extend`
        sources = {
          default = { 'lsp', 'path', 'snippets', 'buffer' },
        },

        -- (Default) Rust fuzzy matcher for typo resistance and significantly better performance
        -- You may use a lua implementation instead by using `implementation = "lua"` or fallback to the lua implementation,
        -- when the Rust fuzzy matcher is not available, by using `implementation = "prefer_rust"`
        --
        -- See the fuzzy documentation for more information
        fuzzy = { implementation = "lua" }
      },
      opts_extend = { "sources.default" }
    },
	-- Treesitter
	{ "nvim-treesitter/nvim-treesitter",  build = ":TSUpdate" }
}

local plugins = {}
tableMerge(plugins_default, plugins)

if not isMinimal then
	tableMerge(plugins_extended, plugins)
end

require("lazy").setup(plugins)

if not isMinimal then
	-- Run command :Mason to manage packages
	-- Commands are prefixed with Mason, they can be cycled by typing :Mason and then TAB
	-- Alternatively, list of LSPs can be found here: https://github.com/mason-org/mason-lspconfig.nvim
    require("mason-lspconfig").setup {
        automatic_enable = true
    }

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
    local treesitter = require('nvim-treesitter')
    treesitter.setup {
      -- Directory to install parsers and queries to (prepended to `runtimepath` to have priority)
      install_dir = vim.fn.stdpath('data') .. '/site'
    }
    -- Install language support
    -- treesitter.install { 'diff', 'dockerfile', 'helm', 'yaml', 'markdown', 'sql', 'lua', 'rust', 'python', 'javascript', 'css', 'typescript', 'tsx', 'go', 'templ', 'c', 'cpp'}

    -- Enable highlighting
    vim.api.nvim_create_autocmd('FileType', {
      pattern = { '<filetype>' },
      callback = function() vim.treesitter.start() end,
    })
    -- Enable indentation
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
end

--[[
telescope.nvim
--------------
https://github.com/nvim-telescope/telescope.nvim
--]]
local telescopeConfig = require("telescope.config")

-- Clone the default Telescope configuration
local vimgrep_arguments = { unpack(telescopeConfig.values.vimgrep_arguments) }

-- I want to search in hidden/dot files.
table.insert(vimgrep_arguments, "--hidden")
-- I don't want to search in the `.git` directory.
table.insert(vimgrep_arguments, "--glob")
table.insert(vimgrep_arguments, "!**/.git/*")

check_if_exec_exists("rg", "rg command (ripgrep) not found, required for telescope: https://github.com/BurntSushi/ripgrep")
require("telescope").setup({
	defaults = {
		vimgrep_arguments = vimgrep_arguments,
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
	pickers = {
		find_files = {
			-- `hidden = true` will still show the inside of `.git/` as it's not `.gitignore`d.
			find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
		},
	},
})

--[[
lualine.nvim
------------
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

-- set color scheme
vim.cmd [[colorscheme tokyonight]]

--[[
-- tabline
-- the following configuration is based on the following repo
-- https://github.com/crispgm/nvim-tabline/
--]]

local nvim_tabline_opt = {
	show_index = true,
	show_modify = true,
	fnamemodify = ':t',
	brackets = { '', '' },
	no_name = 'No Name',
	modify_indicator = ' [+]',
	inactive_tab_max_length = 0,
}

local function tabline(options)
	local s = ''
	for index = 1, vim.fn.tabpagenr('$') do
		local winnr = vim.fn.tabpagewinnr(index)
		local buflist = vim.fn.tabpagebuflist(index)
		local bufnr = buflist[winnr]
		local bufname = vim.fn.bufname(bufnr)
		local bufmodified = vim.fn.getbufvar(bufnr, '&mod')

		s = s .. '%' .. index .. 'T'
		if index == vim.fn.tabpagenr() then
			s = s .. '%#TabLineSel#'
		else
			s = s .. '%#TabLine#'
		end
		-- tab index
		s = s .. ' '
		-- index
		if options.show_index then
			s = s .. index .. ':'
		end
		-- buf name
		s = s .. options.brackets[1]
		local pre_title_s_len = string.len(s)
		if bufname ~= '' then
			s = s .. vim.fn.fnamemodify(bufname, options.fnamemodify)
		else
			s = s .. options.no_name
		end
		if
			options.inactive_tab_max_length
			and options.inactive_tab_max_length > 0
			and index ~= vim.fn.tabpagenr()
		then
			s = string.sub(
				s,
				1,
				pre_title_s_len + options.inactive_tab_max_length
			)
		end
		s = s .. options.brackets[2]
		-- modify indicator
		if
			bufmodified == 1
			and options.show_modify
			and options.modify_indicator ~= nil
		then
			s = s .. options.modify_indicator
		end
		-- additional space at the end of each tab segment
		s = s .. ' '
	end

	s = s .. '%#TabLineFill#'
	return s
end

function _G.nvim_tabline()
	return tabline(nvim_tabline_opt)
end

vim.o.tabline = '%!v:lua.nvim_tabline()'
vim.opt.showtabline = 2

--[[
NvimTree
--------
https://github.com/nvim-tree/nvim-tree.lua
--]]
-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- optionally enable 24-bit colour
vim.opt.termguicolors = true

-- empty setup using defaults
require("nvim-tree").setup()

-- OR setup with some options
require("nvim-tree").setup({
	sort = {
		sorter = "case_sensitive",
	},
	view = {
		width = 30,
	},
	renderer = {
		group_empty = true,
	},
	filters = {
		dotfiles = false,
	},
})

------------------
-- Other checks --
------------------
check_if_exec_exists("xsel", "xsel command not found, required for clipboard operations")

--[[
===========
Keybindings
===========

vim.keymap.set({mode}, {lhs}, {rhs}, {opts})

Modes:
n	: Normal mode
i	: Insert mode
x	: Visual mode
s	: Selection mode
v	: Visual + Selection
t	: Terminal mode
o	: Operator-pending
''	: Equivalent of n + v + o

{lhs}	: Key to bind
{rhs}	: Action to execute, string command or Lua function
--]]

-- Set <leader> to space
vim.g.mapleader = ' '
-- File
vim.keymap.set('n', '<LEADER>w', '<CMD>write<CR>', { desc = '[normal] Write to file' })
-- Clipboard
vim.keymap.set({ 'n', 'x' }, '<LEADER>y', '"+y', { desc = '[normal+visual] Copy to system clipboard' })
vim.keymap.set({ 'n', 'x' }, '<LEADER>p', '"+p', { desc = '[normal+visual] Paste from system clipboard' })
vim.keymap.set({ 'n', 'x' }, 'x', '"_x', { desc = '[normal+visual] Deleting does not change registers' })
vim.keymap.set({ 'n', 'x' }, 'X', '"_d', { desc = '[normal+visual] Deleting does not change registers' })
-- Selection
vim.keymap.set('n', '<LEADER>a', ':keepjumps normal! ggVG<CR>', { desc = '[normal] Select all' })
-- Scrolling
vim.keymap.set({ 'n', 'x' }, '<C-k>', '7<C-y>', { desc = '[normal+visual] Scroll up 7 lines with when pressing CTRL+k' })
vim.keymap.set({ 'n', 'x' }, '<C-j>', '7<C-e>', { desc = '[normal+visual] Scroll down 7 lines with when pressing CTRL+j' })
-- Cursor navigation in input mode
vim.keymap.set('i', '<C-k>', '<Up>', { desc = '[input] Cursor up when pressing CTRL+k' })
vim.keymap.set('i', '<C-j>', '<Down>', { desc = '[input] Cursor down when pressing CTRL+j' })
vim.keymap.set('i', '<C-h>', '<Left>', { desc = '[input] Cursor left when pressing CTRL+h' })
vim.keymap.set('i', '<C-l>', '<Right>', { desc = '[input] Cursor right when pressing CTRL+l' })
-- Wrap selection with quote
vim.keymap.set('x', '<LEADER>"', 'c"<C-r>""<ESC>', { desc = '[visual] Wrap selection with double quote' })
vim.keymap.set('x', '<LEADER>\'', 'c\'<C-r>"\'<ESC>', { desc = '[visual] Wrap selection with single quote' })

-- telescope.nvim
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<LEADER>ff', builtin.find_files, { desc = '[normal] Telescope fuzzy find files' })
vim.keymap.set('n', '<LEADER>fg', builtin.live_grep, { desc = '[normal] Telescope fuzzy live grep' })
vim.keymap.set('n', '<LEADER>fb', builtin.buffers, { desc = '[normal] Telescope fuzzy find buffers' })
vim.keymap.set('n', '<LEADER>fh', builtin.help_tags, { desc = '[normal] Telescope help' })
vim.keymap.set('n', '<LEADER>fl', builtin.builtin, { desc = '[normal] Telescope list pickers' })

-- Tabs can be traversed with 'gt' and 'gT', thus the following
-- bindings were also added with 'g' prefix
-- use '1gtT', '2gt', '3gt', etc. to go to specific tab
-- https://neovim.io/doc/user/tabpage.html

-- Tabs
vim.keymap.set('n', '<LEADER>tc', ':tab split<CR>', { desc = '[normal] Create new tab with current buffer' })
vim.keymap.set('n', '<LEADER>tx', ':tabc<CR>', { desc = '[normal] Close current tab' })
vim.keymap.set({ 'n', 'i' }, '<C-Left>', '<ESC>:tabnext -1<CR>', { remap = false, desc = '[normal] Go to the previous tab' })
vim.keymap.set({ 'n', 'i' }, '<C-Right>', '<ESC>:tabnext +1<CR>', { remap = false, desc = '[normal] Go to the next tab' })
vim.keymap.set({ 'n', 'i' }, '<C-Up>', '<ESC>:tabm -1<CR>', { remap = false, desc = '[normal] Move current tab to left' })
vim.keymap.set({ 'n', 'i' }, '<C-Down>', '<ESC>:tabm +1<CR>', { remap = false, desc = '[normal] Move current tab to right' })

-- nvim-tree
vim.keymap.set('n', '<LEADER>dx', '<ESC>:NvimTreeToggle<CR>', { desc = '[normal] NvimTree toggle visibility' })
vim.keymap.set('n', '<LEADER>dd', '<ESC>:NvimTreeFocus<CR>', { desc = '[normal] NvimTree toggle visible and focus' })
vim.keymap.set('n', '<LEADER>df', '<ESC>:NvimTreeFindFile<CR>', { desc = '[normal] NvimTree toggle and find files' })
vim.keymap.set('n', '<LEADER>dc', '<ESC>:NvimTreeCollapse<CR>', { desc = '[normal] NvimTree collapse recursively' })

-- Block comment patterns
local block_comments_pattern_fallback = {
  lua = { "--[[", "]]" },
  python = { '"""', '"""' },
  sh = { ": <<'COMMENT'", "COMMENT" },
}
-- Line comments
vim.keymap.set("x", "<LEADER>cc", "gc", { remap = true, desc = "[visual] Toggle line comment" })
-- Block comments
vim.keymap.set("x", "<LEADER>cb", function()
  local buf = 0
  local left, right = vim.bo[buf].commentstring:match("^(.-)%%s(.-)$")
  left, right = left and vim.trim(left), right and vim.trim(right)

  if not right or right == "" then
    left, right = unpack(block_comments_pattern_fallback[vim.bo[buf].filetype] or {})
  end

  if not left or not right then
    vim.notify("Block comment unavailable", vim.log.levels.WARN)
    return
  end

  local s, e = vim.fn.line("'<"), vim.fn.line("'>")
  local lines = vim.api.nvim_buf_get_lines(buf, s - 1, e, false)
  local indent, content = lines[1]:match("^(%s*)(.*)$")
  local commented = content:sub(1, #left) == left
    and lines[#lines]:sub(-#right) == right

  if commented then
    lines[1] = indent .. content:sub(#left + 1):gsub("^%s?", "")
    lines[#lines] = lines[#lines]:gsub("%s?" .. vim.pesc(right) .. "$", "")
  else
    lines[1] = indent .. left .. " " .. content
    lines[#lines] = lines[#lines] .. " " .. right
  end

  vim.api.nvim_buf_set_lines(buf, s - 1, e, false, lines)
end, { desc = "[visual] Toggle block comment" })

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

-- Type :CustomInfo to show custom_info_text in a read-only split.
-- Ex command names must start with an uppercase letter and cannot contain
-- underscores, so ':custom_info' is wired up below as an abbreviation for it.
vim.api.nvim_create_user_command("CustomInfo", function()
	open_string_readonly(custom_info_text, "Custom Info")
end, {
	desc = "Shows the custom info text in a read-only split.",
})
-- Expand 'custom_info' to 'CustomInfo', but only when it is the whole command line
vim.cmd([[cnoreabbrev <expr> custom_info (getcmdtype() ==# ':' && getcmdline() ==# 'custom_info') ? 'CustomInfo' : 'custom_info']])

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
-- Find the word with 'T' in the visible buffer
vim.keymap.set('',
	'T', function()
		hop.hint_words({ direction = nil, current_line_only = false })
	end,
	{ remap = true })
