return {

	{
		"nvim-telescope/telescope.nvim",
		version = "*",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {},
	},

	{
		"nvim-telescope/telescope-fzf-native.nvim",
		build = "make",
	},
}
