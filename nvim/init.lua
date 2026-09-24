-- set leader
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- plugins are managed by vim.pack and configured in plugin/*.lua, which nvim
-- sources alphabetically after this file. update with :lua vim.pack.update()

-- plugin build hooks. must be registered before the first vim.pack.add(), which
-- installs everything missing from the lockfile, not just its own plugins
vim.api.nvim_create_autocmd("PackChanged", {
	callback = function(ev)
		if ev.data.spec.name == "nvim-treesitter" and ev.data.kind == "update" then
			if not ev.data.active then
				vim.cmd.packadd("nvim-treesitter")
			end
			vim.cmd("TSUpdate")
		end
		if ev.data.spec.name == "markdown-preview.nvim" and ev.data.kind ~= "delete" then
			if not ev.data.active then
				vim.cmd.packadd("markdown-preview.nvim")
			end
			-- downloads the prebuilt server, skipped if already up to date
			vim.fn["mkdp#util#install_sync"](true)
		end
	end,
})

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

-- use full terminal colors
vim.o.termguicolors = true

-- rounded borders on all floating windows
vim.o.winborder = "rounded"

-- use natural line wrapping
-- vim.wo.wrap = "linebreak"
vim.opt.linebreak = true

vim.o.spell = false
vim.o.spelllang = "en"
vim.o.spellfile = vim.fn.stdpath("config") .. "/spell/en.utf-8.add"

-- load project-local config
vim.o.exrc = true

-- diagnostic virtual text at the of the line
vim.diagnostic.config({
	virtual_text = {},
})

vim.filetype.add({
	extension = {
		pest = "pest",
	}
})

-- enable treesitter highlighting for all filetypes with an installed parser
vim.api.nvim_create_autocmd("FileType", {
	pattern = "*",
	callback = function() pcall(vim.treesitter.start) end,
})

-- highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.hl.on_yank()
	end,
	pattern = "*",
})

-- create missing parent directories on write
vim.api.nvim_create_autocmd("BufWritePre", {
	callback = function(ev)
		local name = vim.api.nvim_buf_get_name(ev.buf)
		if vim.bo[ev.buf].buftype ~= "" or name == "" or name:match("^%w+://") then
			return
		end
		vim.fn.mkdir(vim.fn.fnamemodify(name, ":p:h"), "p")
	end,
})
