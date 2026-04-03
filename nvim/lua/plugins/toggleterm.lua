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
					if vim.o.columns > 150 then
						vim.cmd("ToggleTerm99 size=80 direction=vertical")
					else
						vim.cmd("ToggleTerm99 size=20 direction=horizontal")
					end
				end,
				desc = "Toggle terminal"
			},
			{ "<esc>", [[<C-\><C-n><C-w><C-w>]], desc = "Leave terminal mode", mode = "t" },
			{ "L", "<cmd>ToggleTermSendCurrentLine99<cr>", desc = "send line to terminal" },
			{ "L", "<cmd>ToggleTermSendVisualSelection99<cr>", desc = "send selection to terminal", mode = "x" },
		}
	},
}
