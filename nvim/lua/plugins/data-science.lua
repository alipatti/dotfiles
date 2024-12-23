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
			{
				"<leader>qr",
				"<cmd>ToggleTermSendCurrentLine<cr>",
				desc = "run current line",
				mode = "n",
			},
			{
				"<leader>qr",
				"<cmd>'<,'>ToggleTermSendVisualLines<cr>",
				desc = "run selection",
				mode = "v",
			}
		},
	},

	{
		"jmbuhr/otter.nvim",
		opts = {},
	},

}
