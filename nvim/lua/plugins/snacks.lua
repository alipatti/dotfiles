return {
	{
		"folke/snacks.nvim",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
		priority = 1000,
		lazy = false,
		config = function(_, opts)
			require("snacks").setup(opts)
			vim.api.nvim_set_hl(0, "SnacksIndent", { link = "LineNr" })
		end,
		opts = {
			picker = {
				enabled = true,
				layout = {
					layout = {
						backdrop = 80,
					},
				},
				sources = {
					explorer = {
						matcher = {
							fuzzy = true,
						},
						auto_close = true,
						layout = {
							preset = "vertical",
							layout = { max_width = 50 }
						},
					}
				}
			},
			indent = {
					only_current = true,
				indent = {
					char = "▎",
				},
				animate = {
					enabled = false,
				},
				scope = {
					enabled = true,
					char = "▎",
					hl = "Comment",
				},
			},
			bufdelete = {
				enabled = true
			},
			input = {
				enabled = true
			},
			explorer = {
				enabled = true,
				replace_netrw = true,
				trash = true, -- use the system trash when deleting files
			},
		},
		keys = {
			-- LSP/DIAGNOSTICS
			{
				";R",
				function() Snacks.picker.lsp_references() end,
				desc = "go to references"
			},
			{
				"<leader>sl",
				function() Snacks.picker.lsp_symbols() end,
				desc = "LSP symbols (current file)"
			},
			{
				"<leader>sL",
				function() Snacks.picker.lsp_workspace_symbols() end,
				desc = "LSP symbols (workspace)"
			},
			{
				"<leader>sd",
				function() Snacks.picker.diagnostics() end,
				desc = "diagnostics"
			},
			-- SEARCHING
			{
				"<leader>ss",
				function() Snacks.picker.grep() end,
				desc = "current folder"
			},
			{
				"<leader>sg",
				function() Snacks.picker.git_log() end,
				desc = "git commits"
			},
			-- FILE EXPLORER
			{
				"<leader>f",
				function() Snacks.explorer() end,
				desc = "file explorer"
			},
		},
	}
}
