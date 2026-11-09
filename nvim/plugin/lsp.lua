-- the servers themselves are installed by nix (see home/programs/packages.nix). the
-- keys are lspconfig names; values override lspconfig's default config
local lsp_servers = {
	-- through uvx so the editor matches `uvx ty check` and `uvx ruff check`
	-- instead of nixpkgs' lagging releases
	ty            = { cmd = { "uvx", "ty", "server" } },
	ruff          = { cmd = { "uvx", "ruff", "server" } },
	lua_ls        = {},
	yamlls        = {},
	taplo         = {},
	jsonls        = {},
	fish_lsp      = {},
	svelte        = {},
	tailwindcss   = {},
	-- skip claude code's ctrl-g prompt buffers. not calling on_dir stops attach
	rumdl         = {
		root_dir = function(bufnr, on_dir)
			local name = vim.fs.basename(vim.api.nvim_buf_get_name(bufnr))
			if not name:match("^claude%-prompt%-.*%.md$") then
				on_dir(vim.fs.root(bufnr, { ".rumdl.toml", "rumdl.toml", ".git" }) or vim.fn.getcwd())
			end
		end,
	},
	tinymist      = {},
	nixd          = {},
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
				build = {
					onSave = false,
					executable = "tectonic",
					args = { "-X", "compile", "%f", "--synctex", "--keep-logs", "--keep-intermediates" },
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
