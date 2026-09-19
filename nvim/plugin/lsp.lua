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

	-- web
	svelte        = {},
	tailwindcss   = {},

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

vim.pack.add({
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/mason-org/mason.nvim",
	"https://github.com/mason-org/mason-lspconfig.nvim",
	"https://github.com/folke/lazydev.nvim",
})

require("lazydev").setup({
	library = {
		{ path = "snacks.nvim", words = { "Snacks" } },
	},
})

require("mason").setup()
require("mason-lspconfig").setup({
	ensure_installed = vim.tbl_keys(lsp_servers),
	automatic_enable = true,
})
