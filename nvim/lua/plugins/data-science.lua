return {

	{
		"quarto-dev/quarto-nvim",
		opts = {
			lspFeatures = {
				languages = { "r", "python", "julia", "bash", "html", "lua" },
			},
		},
		ft = "quarto",
		keys = {
			{
				"<leader>qa",
				"<cmd>QuartoActivate<cr>",
				desc = "activate"
			},
			{
				"<leader>qp",
				"<cmd>QuartoPreview<cr>",
				desc = "preview"
			},
			{
				"<leader>qq",
				"<cmd>QuartoClosePreview<cr>",
				desc = "stop preview"
			},
		},
	},

	{
		"jmbuhr/otter.nvim",
		opts = {},
	},

}
