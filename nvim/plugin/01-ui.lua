-- color theme. set before the other plugins load since :colorscheme clears
-- any highlights they define
vim.pack.add({
	{ src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
})

require("catppuccin").setup({
	background = {
		light = "latte",
		dark = "frappe",
	},
})

vim.cmd.colorscheme("catppuccin-frappe")

vim.pack.add({
	"https://github.com/folke/which-key.nvim",
	"https://github.com/folke/todo-comments.nvim",
	"https://github.com/nvim-lua/plenary.nvim", -- todo-comments dependency
	"https://github.com/folke/noice.nvim",
	"https://github.com/MunifTanjim/nui.nvim", -- noice dependency
	"https://github.com/brenoprata10/nvim-highlight-colors",
})

-- shows pending keybinds
require("which-key").setup({
	spec = {
		{
			mode = "n",
			{ ";e", vim.diagnostic.open_float,   desc = "hover diagnostic" },
			{ ";f", vim.lsp.buf.format,          desc = "format buffer" },
			{ ";a", vim.lsp.buf.code_action,     desc = "code actions" },
			{ ";d", vim.lsp.buf.definition,      desc = "go to definition" },
			{ ";D", vim.lsp.buf.declaration,     desc = "go to declaration" },
			{ ";i", vim.lsp.buf.implementation,  desc = "go to implementation" },
			{ ";t", vim.lsp.buf.type_definition, desc = "go to type definition" },
			{ ";r", vim.lsp.buf.rename,          desc = "rename symbol" },
			{ ";h", vim.lsp.buf.hover,           desc = "hover" },
		},
		{
			mode = "i",
			{ "<C-i>", vim.lsp.buf.signature_help, desc = "function signature help" },
			{ "<C-h>", "<Left>",                   desc = "go left" },
			{ "<C-l>", "<Right>",                  desc = "go right" },
		},
		{
			mode = "n",
			{ "U",     "<cmd>redo<cr>", desc = "redo" },
			{ "<D-]>", "<cmd>bn<cr>",   desc = "next buffer" },
			{ "<D-[>", "<cmd>bp<cr>",   desc = "previous buffer" },
		},
	}
})

-- highlight todo comments
require("todo-comments").setup({
	keywords = {
		SECTION = { icon = "§ ", color = "hint" },
		SAFETY = { icon = " ", color = "warning" },
		CLAUDE = { icon = "󰚩 ", color = "info" },
	},
})

-- pop up cmd line
require("noice").setup({
	routes = {
		{
			view = "popup",
			filter = { cmdline = "^:!" },
		},
	},
})

-- highlight color codes inline
require("nvim-highlight-colors").setup({
	render = "virtual",
	virtual_symbol = "●",
	virtual_symbol_position = "eol",
})
