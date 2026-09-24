-- the servers themselves are installed by nix (see home/packages.nix). the
-- keys are lspconfig names; values override lspconfig's default config
local lsp_servers = {
	pyright       = {},
	ruff          = {},
	lua_ls        = {},
	yamlls        = {},
	taplo         = {},
	jsonls        = {},
	fish_lsp      = {},
	svelte        = {},
	tailwindcss   = {},
	rumdl         = {},
	tinymist      = {},
	rust_analyzer = {
		settings = {
			["rust-analyzer"] = {
				cargo = { targetDir = true },
			},
		},
	},
	texlab        = {
		settings = {
			texlab = {
				forwardSearch = {
					executable = "/Applications/Skim.app/Contents/SharedSupport/displayline",
					args = { "-background", "%l", "%p" },
				},
				build = {
					onSave = false,
					args = { "%f" },
				},
				latexindent = {
					modifyLineBreaks = true,
				},
			},
		},
	},
}

vim.pack.add({
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/folke/lazydev.nvim",
})

require("lazydev").setup({
	library = {
		{ path = "snacks.nvim", words = { "Snacks" } },
	},
})

for server, config in pairs(lsp_servers) do
	vim.lsp.config(server, config)
end
vim.lsp.enable(vim.tbl_keys(lsp_servers))
