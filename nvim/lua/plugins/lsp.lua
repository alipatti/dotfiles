-- LSPs to be installed
local lsp_servers = {
	-- rust
	rust_analyzer = {
		['rust-analyzer'] = {
			cargo = { targetDir = true }
		}
	},

	-- latex
	texlab = {
		texlab = {
			forwardSearch = {
				executable = '/Applications/Skim.app/Contents/SharedSupport/displayline',
				args = { "-background", '%l', '%p', },
			},
			build = {
				onSave = false,
				args = { "%f" }
			},
			latexindent = {
				modifyLineBreaks = true
			}
		}
	}
}

return {
	-- LSP plugins and config
	{
		"mason-org/mason-lspconfig.nvim",
		dependencies = {
			{ "neovim/nvim-lspconfig", },
			{ "mason-org/mason.nvim",  opts = {} },
			{ "j-hui/fidget.nvim",     opts = {}, tag = "legacy" },
			{ "folke/lazydev.nvim",    opts = {} },
			{ "hrsh7th/cmp-nvim-lsp",  opts = {} },

		},
		opts = {
			automatic_enable = true,
		},
	},

	{
		"nvimtools/none-ls.nvim",
		config = function()
			require("null-ls").setup({
				sources = {
					require("null-ls").builtins.formatting.prettier,
					require("null-ls").builtins.diagnostics.markdownlint,

					-- fish
					require("null-ls").builtins.diagnostics.fish,
					require("null-ls").builtins.formatting.fish_indent,

					-- swift
					require("null-ls").builtins.formatting.swiftlint,
					require("null-ls").builtins.formatting.swiftformat,
				}
			})
		end
	},


}
