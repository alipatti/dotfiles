return {

	{
		"nvim-telescope/telescope.nvim",
		dependencies = { "nvim-lua/plenary.nvim", 'nvim-telescope/telescope-ui-select.nvim' },
		opts = {},
		keys = {
			{ ";R",         "<cmd>Telescope lsp_references theme=dropdown<cr>",            desc = "go to references" },
			{ "<leader>ss", "<cmd>Telescope live_grep theme=dropdown<cr>",                 desc = "current folder" },
			{ "<leader>sl", "<cmd>Telescope lsp_document_symbols theme=dropdown<cr>",      desc = "LSP symbols" },
			{ "<leader>sL", "<cmd>Telescope lsp_workspace_symbols theme=dropdown<cr>",     desc = "LSP symbols" },
			{ "<leader>sc", "<cmd>Telescope current_buffer_fuzzy_find theme=dropdown<cr>", desc = "within current buffer" },
			{ "<leader>sd", "<cmd>Telescope diagnostics theme=dropdown<cr>",               desc = "diagnostics" },
			{ "<leader>sg", "<cmd>Telescope git_commits<cr>",                              desc = "git commits" },
		}
	},

	{
		"nvim-telescope/telescope-fzf-native.nvim",
		build = "make",
	},

	{
		"aznhe21/actions-preview.nvim",
		dependencies = { "nvim-telescope/telescope.nvim" },
		keys         = function(plugin, keys)
			return { ";a", plugin.code_actions, desc = "code actions" }
		end,
		opts         = {
			telescope = {
				sorting_strategy = "ascending",
				layout_strategy = "vertical",
				layout_config = {
					width = 0.8,
					height = 0.9,
					prompt_position = "top",
					preview_cutoff = 20,
					preview_height = function(_, _, max_lines)
						return max_lines - 15
					end,
				},
			},
		}
	}
}
