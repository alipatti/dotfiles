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
	rumdl         = {},

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
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				{ path = "snacks.nvim", words = { "Snacks" } },
			},
		},
	},

	{
		"mason-org/mason-lspconfig.nvim",
		dependencies = {
			{ "neovim/nvim-lspconfig", },
			{ "mason-org/mason.nvim",  opts = {} },
			{ "j-hui/fidget.nvim",     opts = {}, tag = "legacy" },
			{ "hrsh7th/cmp-nvim-lsp",  opts = {} },

		},
		opts = {
			ensure_installed = vim.tbl_keys(lsp_servers),
			automatic_enable = true,
		},
	},
}
