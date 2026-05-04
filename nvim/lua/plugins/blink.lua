_ = {
	{
		"saghen/blink.cmp",
		dependencies = {
			"Kaiser-Yang/blink-cmp-git",
			"disrupted/blink-cmp-conventional-commits",
		},
		version = "*",
		opts = {
			keymap = {
				preset = "default",
				["<C-c>"] = { "cancel", "fallback" },
				["<C-Space>"] = { "select_and_accept" },
			},
			signature = { enabled = false },
			sources = {
				default = { "lsp", "path", "git", "conventional_commits" },
				providers = {
					git = {
						name = "Git",
						module = "blink-cmp-git",
					},
					conventional_commits = {
						name = "Conventional Commits",
						module = "blink-cmp-conventional-commits",
						enabled = function()
							return vim.bo.filetype == "gitcommit"
						end,
					},
				},
			},
			completion = {
				documentation = {
					auto_show = true,
					window = {
						border = "rounded",
						max_width = 80,
					},
				},
			},
		},
	},
}

return {}
