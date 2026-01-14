return {
	{
		"nvim-treesitter/nvim-treesitter",
		dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
		build = ":TSUpdate",
		lazy = false,
		branch = "master",
		config = function()
			require("nvim-treesitter.configs").setup({
				-- languages to be installed
				ensure_installed = {
					"lua",
					"vimdoc",
					"python",
					"r",
					"latex",
					"javascript",
					"typescript",
					"tsx",
					"html",
				},

				-- https://github.com/nvim-treesitter/nvim-treesitter?tab=readme-ov-file#highlight
				highlight = {
					enable = true,
					-- Setting this to true will run `:h syntax` and tree-sitter at the same time.
					-- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
					-- Using this option may slow down your editor, and you may see some duplicate highlights.
					-- Instead of true it can also be a list of languages
					additional_vim_regex_highlighting = false,
				},

				-- synchronous or async installation
				sync_install = false,

				modules = {},
				ignore_install = {},

				-- add uninstalled languages automatically
				auto_install = false,

				incremental_selection = {
					enable = true,
					keymaps = {
						init_selection = "<C-k>",
						node_incremental = "<C-k>",
						-- scope_incremental = "<C-s>",
						node_decremental = "<C-j>",
					},
				},

				textobjects = {
					select = {
						enable = true,
						-- Automatically jump forward to textobj, similar to targets.vim
						lookahead = true,
						keymaps = {
							-- function parameters
							["aa"] = "@parameter.outer",
							["ia"] = "@parameter.inner",
							-- functions
							["af"] = "@function.outer",
							["if"] = "@function.inner",
							-- classes
							["ac"] = "@class.outer",
							["ic"] = "@class.inner",
						},
					},
					move = {
						enable = true,
						set_jumps = true, -- whether to set jumps in the jumplist
						goto_next_start = {
							["]m"] = "@function.outer",
							["]]"] = "@class.outer",
						},
						goto_next_end = {
							["]M"] = "@function.outer",
							["]["] = "@class.outer",
						},
						goto_previous_start = {
							["[m"] = "@function.outer",
							["[["] = "@class.outer",
						},
						goto_previous_end = {
							["[M"] = "@function.outer",
							["[]"] = "@class.outer",
						},
					},
				}
			})
		end
	},

	{
		-- auto close/rename html (and other) tags
		"windwp/nvim-ts-autotag",
	},

	-- 	{
	-- 		-- show context at top of screen when scrolling
	-- 		"nvim-treesitter/nvim-treesitter-context",
	-- 		config = function()
	-- 			require("treesitter-context").setup({
	-- 				separator = "—",
	-- 			})
	-- 			vim.api.nvim_set_hl(0, "TreesitterContextSeparator", { link = "LineNr" })
	-- 			vim.api.nvim_set_hl(0, "TreesitterContext", { link = "Normal" })
	-- 		end,
	-- 	}
}
