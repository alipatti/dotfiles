-- alipatti's nvim configuration

-- TODO:
-- - add keymaps for creating a new file, editing a specific file, etc.
-- - add keymaps for git (blame, hunk-related, etc.)

-- set leader
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-------------
-- PLUGINS --
-------------

-- use lazy.nvim as the package manager
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

require("lazy").setup("plugins")

-------------
-- KEYMAPS --
-------------

require("keymaps")
require("highlight-on-yank")

----------
-- MISC --
----------

-- highlight on search
vim.o.hlsearch = false

-- make line numbers default
vim.wo.number = true

vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true

-- enable mouse mode
vim.o.mouse = "a"

-- sync clipboard between OS and Neovim.
vim.o.clipboard = "unnamedplus"

-- enable break indent
vim.o.breakindent = true

-- save undo history
vim.o.undofile = true

-- case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- keep signcolumn on by default
vim.wo.signcolumn = "yes"

-- decrease update time
vim.o.updatetime = 250
vim.o.timeout = true
vim.o.timeoutlen = 300

-- set completeopt to have a better completion experience
vim.o.completeopt = "menuone,noselect"

-- use full terminal colors
vim.o.termguicolors = true

-- use natural line wrapping
-- vim.wo.wrap = "linebreak"
vim.opt.linebreak = true

-- set color scheme
vim.cmd.colorscheme "catppuccin-frappe"

vim.filetype.add({
	extension = {
		sage = "python",
	}
})
