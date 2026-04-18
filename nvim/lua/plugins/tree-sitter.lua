return {
	{
		"neovim-treesitter/nvim-treesitter",
		dependencies = {
			"neovim-treesitter/treesitter-parser-registry",
			"nvim-treesitter/nvim-treesitter-textobjects",
		},
		build = ":TSUpdate",
		lazy = false,
		config = function()
			require("nvim-treesitter").setup()

			require("nvim-treesitter").install({
				"lua", "vimdoc", "python", "r", "latex",
				"javascript", "typescript", "tsx", "html",
				"yaml", "typst", "toml", "json", "fish", "markdown", "rust",
				"dockerfile", "gitcommit", "gitignore", "gitattributes",
			})

			-- enable highlighting for all filetypes with an installed parser
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "*",
				callback = function() pcall(vim.treesitter.start) end,
			})

			-- incremental selection via native neovim 0.12 api
			local sel = require("vim.treesitter._select")
			vim.keymap.set("n", "<C-k>", function() sel.select_parent(vim.v.count1) end, { silent = true })
			vim.keymap.set("x", "<C-k>", function() sel.select_parent(vim.v.count1) end, { silent = true })
			vim.keymap.set("x", "<C-j>", function() sel.select_child(vim.v.count1) end, { silent = true })
		end,
	},

	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		config = function()
			require("nvim-treesitter-textobjects").setup({
				select = {
					enable = true,
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
					set_jumps = true,
					goto_next_start = {
						["]]"] = "@function.outer",
					},
					goto_previous_start = {
						["[["] = "@function.outer",
					},
				},
			})
		end,
	},

	-- {
	-- 	-- auto close/rename html (and other) tags
	-- 	"windwp/nvim-ts-autotag",
	-- },
}
