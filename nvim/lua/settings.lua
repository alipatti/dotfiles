-- highlight on search
vim.o.hlsearch = true

-- make line numbers default
vim.wo.number = true

-- tab == four spaces
vim.opt_local.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true

-- enable mouse mode
vim.o.mouse = "a"

-- sync clipboard between OS and Neovim.
vim.o.clipboard = "unnamedplus"

-- enable break indent
vim.o.breakindent = true

-- relative line numbers
vim.opt.relativenumber = true

-- save undo history
vim.o.undofile = true

-- case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- keep signcolumn on by default
vim.wo.signcolumn = "yes"

-- set completeopt to have a better completion experience
vim.o.completeopt = "menuone,noselect"

-- use full terminal colors
vim.o.termguicolors = true

-- use natural line wrapping
-- vim.wo.wrap = "linebreak"
vim.opt.linebreak = true

-- set color scheme
vim.cmd.colorscheme "catppuccin-frappe"

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

-- tab == 2 spaces when i'm using tex
vim.api.nvim_create_autocmd("FileType", {
	pattern = "tex",
	callback = function()
		vim.opt_local.tabstop = 2
		vim.opt_local.shiftwidth = 2
		vim.opt_local.expandtab = true
	end,
})
