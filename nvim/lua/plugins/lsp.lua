-- LSPs to be installed
local lsp_servers = {
	-- python
	pyright       = {},
	ruff          = {},

	-- lua
	lua_ls        = {},

	-- yaml
	yamlls        = {},

	-- toml
	taplo         = {}, --

	-- json
	jsonls        = {},

	-- fish
	fish_lsp      = {},

	-- markdown
	marksman      = {},

	-- typst
	tinymist      = {
		rootPath = vim.fn.getcwd(),
	},

	-- rust
	rust_analyzer = {
		['rust-analyzer'] = {
			cargo = { targetDir = true }
		}
	},

	-- latex
	texlab        = {
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

for server, config in pairs(lsp_servers) do
	if next(config) then
		vim.lsp.config(server, { settings = config })
	end
end

return {
	-- LSP plugins and config
	{ "folke/lazydev.nvim", ft = "lua", opts = {} },

	{
		"mason-org/mason-lspconfig.nvim",
		dependencies = {
			{ "neovim/nvim-lspconfig", },
			{ "mason-org/mason.nvim",  opts = { ensure_installed = { "prettier" } } },
			{ "j-hui/fidget.nvim",     opts = {},                                   tag = "legacy" },
			{ "hrsh7th/cmp-nvim-lsp",  opts = {} },

		},
		opts = {
			ensure_installed = vim.tbl_keys(lsp_servers),
			automatic_enable = true,
		},
	},

	{
		"nvimtools/none-ls.nvim",
		config = function()
			require("null-ls").setup({
				sources = {
					-- TODO: remove this (superceded by lsp)
					-- require("null-ls").builtins.formatting.prettier,
					-- require("null-ls").builtins.diagnostics.markdownlint,

					-- TODO: remove this (superceded by lsp)
					-- -- fish
					-- require("null-ls").builtins.diagnostics.fish,
					-- require("null-ls").builtins.formatting.fish_indent,

					-- swift
					require("null-ls").builtins.formatting.swiftlint,
					require("null-ls").builtins.formatting.swiftformat,
				}
			})
		end
	},


}
