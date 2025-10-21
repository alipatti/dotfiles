return {
	-- adds git releated signs to the gutter, as well as utilities for managing changes
	{
		"lewis6991/gitsigns.nvim",
		lazy = false,
		opts = {
			numhl               = false,
			signcolumn          = true,
			attach_to_untracked = true,
		},
		keys = {
			{ "<leader>gh", "<cmd>Gitsigns preview_hunk_inline<cr>",                           desc = "diff hunk (inline)" },
			{ "<leader>gr", "<cmd>Gitsigns reset_hunk<cr>",                                    desc = "reset hunk" },
			{ "<leader>gb", "<cmd>Gitsigns toggle_current_line_blame<cr>",                     desc = "toggle blame" },
			{ "<leader>gd", "<cmd>Gitsigns toggle_linehl<cr><cmd>Gitsigns toggle_deleted<cr>", desc = "diff file (side-by-side)" },
			{ "<leader>gD", "<cmd>Gitsigns diffthis<cr><cmd>vertical wincmd h<cr>",            desc = "diff file (side-by-side)" },
		},
	},
}
