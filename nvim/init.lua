-- set leader
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- set up package manager
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

-- highlight on search
vim.o.hlsearch = true

-- relative line numbering
vim.wo.number = true
vim.o.relativenumber = true

-- keep signcolumn on by default
vim.wo.signcolumn = "yes"

-- tab = four spaces
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true

-- sync clipboard between OS and Neovim.
vim.o.clipboard = "unnamedplus"

-- enable break indent
vim.o.breakindent = true

-- save undo history
vim.o.undofile = true

-- case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- set completeopt to have a better completion experience
vim.o.completeopt = "menuone,noselect"

-- use full terminal colors
vim.o.termguicolors = true

-- use natural line wrapping
-- vim.wo.wrap = "linebreak"
vim.opt.linebreak = true

-- set color scheme
vim.cmd.colorscheme("catppuccin-frappe")

-- diagnostic virtual text at the of the line
vim.diagnostic.config({
	virtual_text = {},
})

vim.filetype.add({
	extension = {
		sage = "python",
		pest = "pest",
	}
})

-- highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
	pattern = "*",
})

