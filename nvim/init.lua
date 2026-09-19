-- set leader
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- set up package manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
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

-- completion menu: always show it, preselect nothing, docs in a popup beside it
vim.o.completeopt = "menuone,noselect,popup,fuzzy"
vim.o.pumborder = "rounded"

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

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "tex", "markdown", "typst" },
    callback = function() vim.opt_local.spell = true end,
})

-- load project-local config
vim.o.exrc = true

-- set color scheme
vim.cmd.colorscheme("catppuccin-frappe")

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

-- native lsp completion, triggered on every keystroke
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
		if not client:supports_method("textDocument/completion") then
			return
		end

		-- autotrigger only fires on the server's trigger characters, so make
		-- every printable non-space character one (see :help lsp-autocompletion)
		local chars = {}
		for i = 33, 126 do
			table.insert(chars, string.char(i))
		end
		client.server_capabilities.completionProvider.triggerCharacters = chars

		vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
	end,
})

-- accept the selected completion item, or the first one if none is selected.
-- with no menu open, request lsp completion instead
vim.keymap.set("i", "<C-Space>", function()
	if vim.fn.pumvisible() == 0 then
		vim.schedule(vim.lsp.completion.get)
		return ""
	end
	local selected = vim.fn.complete_info({ "selected" }).selected
	return selected == -1 and "<C-n><C-y>" or "<C-y>"
end, { expr = true, desc = "accept completion" })

-- dismiss the completion menu
vim.keymap.set("i", "<C-c>", function()
	return vim.fn.pumvisible() == 1 and "<C-e>" or "<C-c>"
end, { expr = true, desc = "dismiss completion" })
