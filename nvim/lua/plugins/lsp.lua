-- LSPs to be installed
local lsp_servers = {
	-- python type checking
	-- TODO: remove this when ruff type checker comes out
	pyright = {
		pyright = {
			-- using ruff's import organizer
			disableOrganizeImports = true,
		},
	},

	-- astral python tools
	ruff = {}, -- linter/formatter
	-- ty = {}, -- type checker

	-- rust
	rust_analyzer = {
		['rust-analyzer'] = {
			cargo = { targetDir = true }
		}
	},

	-- web development
	html = {},
	denols = {},
	cssls = {},
	emmet_ls = {},

	-- r
	r_language_server = {},

	pest_ls = {
		filetypes = { "pest" },
	},

	-- lua
	lua_ls = {},

	-- quarto/markdown
	-- marksman = {
	-- 	filetypes = { "markdown", "quarto" },
	-- },

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
		"williamboman/mason-lspconfig.nvim",
		dependencies = {
			{ "neovim/nvim-lspconfig", }, -- TODO: update to new lsp integration in nvim
			{ "williamboman/mason.nvim", opts = {} },
			{ "j-hui/fidget.nvim",       opts = {}, tag = "legacy" },
			{ "folke/neodev.nvim",       opts = {} },
			{ "hrsh7th/cmp-nvim-lsp",    opts = {} },

		},
		config = function()
			-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
			-- local capabilities = vim.lsp.protocol.make_client_capabilities()
			-- capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

			require("mason-lspconfig").setup({
				automatic_enable = true,
				ensure_installed = vim.tbl_keys(lsp_servers),
				automatic_installation = true,
			})
		end
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
