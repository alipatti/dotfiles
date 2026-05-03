return {
	{
		"folke/snacks.nvim",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
		priority = 1000,
		lazy = false,
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
				enabled = true,
				only_current = true, -- only show indent guides in the current window
				-- TODO: make wider box char
				-- TODO: make lighter color
				-- char = "┃",
				char = "▎",
				hl = "SnacksIndent",
				animate = {
					enabled = false,
				},
				scope = {
					enabled = true,
					hl = "SnacksIndentScope",
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
