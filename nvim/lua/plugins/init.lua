return {
	-- color theme
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		opts = {
			background = {
				light = "latte",
				dark = "frappe",
			},
		},
	},

	-- shows pending keybinds
	{
		"folke/which-key.nvim",
		opts = {
			spec = {
				{
					mode = "n",
					{ ";e", vim.diagnostic.open_float,   desc = "Hover diagnostic" },
					{ ";f", vim.lsp.buf.format,          desc = "format buffer" },
					{ ";d", vim.lsp.buf.definition,      desc = "go to definition" },
					{ ";D", vim.lsp.buf.declaration,     desc = "go to declaration" },
					{ ";i", vim.lsp.buf.implementation,  desc = "go to implementation" },
					{ ";t", vim.lsp.buf.type_definition, desc = "go to type definition" },
					{ ";R", vim.lsp.buf.rename,          desc = "rename symbol" },
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
		},

	},

	-- highlight todo comments
	{
		"folke/todo-comments.nvim",
		opts = {},
		dependencies = { "nvim-lua/plenary.nvim" },
	},

	-- adds git releated signs to the gutter, as well as utilities for managing changes
	{
		"lewis6991/gitsigns.nvim",
		opts = {},
	},

	-- add indentation guides and highlighting of current scope
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		opts = {
			scope = { enabled = false },
		}
	},

	-- { "hiphish/rainbow-delimiters.nvim" },

	-- "gc" to comment visual regions/lines
	{
		"numToStr/Comment.nvim",
		opts = {},
	},

	-- automatically create necessary parent directories when creating a new file
	{
		"mateuszwieloch/automkdir.nvim",
		opts = {},
	},

	"tpope/vim-eunuch", -- vim wrappers for mkdir, mv, etc.
	"tpope/vim-sleuth", -- automatically detect indentation
	"tpope/vim-surround", -- surround with quotes, parens, tags, etc.
	-- "tpope/vim-fugitive", -- git support
	"tpope/vim-surround", -- support for editing surround quotes, html tags, etc
}
