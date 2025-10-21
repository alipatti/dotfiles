return {
	{
		'akinsho/toggleterm.nvim',
		version = "*",
		opts = {
			float_opts = { border = "curved" }
		},
		keys = {
			{
				"<leader>t",
				function()
					if vim.api.nvim_win_get_width(0) > 150 then
						require("toggleterm").toggle(nil, 80, nil, "vertical")
					else
						require("toggleterm").toggle(nil, 20, nil, "horizontal")
					end
				end,
				desc = "Toggle terminal"
			},
			{ "<esc>", [[<C-\><C-n><C-w><C-w>]], desc = "Leave terminal mode", mode = "t" },
			{ "L", "<cmd>ToggleTermSendCurrentLine<cr>", desc = "send line to terminal" },
			{ "L", "<cmd>ToggleTermSendVisualSelection<cr>", desc = "send selection to terminal", mode = "x" },
		}
	},
}
