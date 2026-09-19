vim.pack.add({
	-- tagged releases ship a prebuilt fuzzy matcher
	{ src = "https://github.com/saghen/blink.cmp", version = vim.version.range("*") },
	"https://github.com/Kaiser-Yang/blink-cmp-git", -- reference issues, people, etc.
	"https://github.com/disrupted/blink-cmp-conventional-commits",
})

require("blink.cmp").setup({
	keymap = {
		preset = "default",
		["<C-c>"] = { "cancel", "fallback" },
		["<C-Space>"] = { "select_and_accept" },
	},
	signature = { enabled = false },
	-- cmdline completion is handled by noice
	cmdline = { enabled = false },
	sources = {
		default = { "lsp", "path", "git", "conventional_commits" },
		providers = {
			path = {
				-- complete relative to the working directory, not the buffer
				opts = {
					get_cwd = function() return vim.fn.getcwd() end,
				},
			},
			git = {
				name = "Git",
				module = "blink-cmp-git",
				enabled = function()
					return vim.bo.filetype == "gitcommit"
				end,
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
		list = {
			-- nothing selected until <C-n>/<C-p>; <C-Space> takes the first item
			selection = { preselect = false, auto_insert = true },
		},
		menu = {
			border = "rounded",
		},
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 0,
			window = {
				border = "rounded",
				max_width = 100,
			},
		},
	},
})
