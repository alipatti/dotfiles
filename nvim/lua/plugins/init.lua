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

	"lervag/vimtex", -- latex plugin

	-- shows pending keybinds
	{
		"folke/which-key.nvim",
		opts = {},
	},

	-- highlight todo comments
	{
		"folke/todo-comments.nvim",
		opts = {},
		dependencies = { "nvim-lua/plenary.nvim" },
	},

	-- LSP plugins and config
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			{
				"williamboman/mason.nvim",
				opts = {},
			},
			"williamboman/mason-lspconfig.nvim",
			{
				"j-hui/fidget.nvim",
				opts = {},
			},

			"folke/neodev.nvim",
		},
	},

	-- autocomplete
	{
		"hrsh7th/nvim-cmp",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"L3MON4D3/LuaSnip",
			"saadparwaiz1/cmp_luasnip",
			"hrsh7th/cmp-omni",
		},
	},


	-- floating terminal
	{
		'akinsho/toggleterm.nvim',
		version = "*",
		opts = {
			float_opts = { border = "curved" }
		}
	},

	-- adds git releated signs to the gutter, as well as utilities for managing changes
	{
		"lewis6991/gitsigns.nvim",
		opts = {},
	},

	-- Add indentation guides even on blank lines
	{
		"lukas-reineke/indent-blankline.nvim",
		opts = {
			show_trailing_blankline_indent = false,
			show_current_context_start = true,
		},
	},

	-- "gc" to comment visual regions/lines
	{
		"numToStr/Comment.nvim",
		opts = {},
	},
}
