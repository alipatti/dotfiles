-- LSPs to be installed
local lsp_servers = {
	pyright = {},

	-- rust
	rust_analyzer = {},

	-- web development
	html = {},
	cssls = {},
	emmet_ls = {},

	-- latex
	texlab = {
		texlab = {
			forwardSearch = {
				executable = '/Applications/Skim.app/Contents/SharedSupport/displayline',
				args = { "-background", "-readingbar", '%l', '%p', },
			},
			build = {
				onSave = true,
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
			{ "neovim/nvim-lspconfig", },
			{
				"weilbith/nvim-code-action-menu",
				config = function()
					vim.g.code_action_menu_window_border = "rounded"
					vim.g.code_action_menu_show_details = false
				end
			},
			{ "williamboman/mason.nvim", opts = {} },
			{ "j-hui/fidget.nvim",       opts = {} },
			{ "folke/neodev.nvim",       opts = {} },
			{ "hrsh7th/cmp-nvim-lsp",    opts = {} },

		},
		config = function()
			-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

			require("mason-lspconfig").setup({
				ensure_installed = vim.tbl_keys(lsp_servers),
			})

			require("mason-lspconfig").setup_handlers({
				function(server_name)
					require("lspconfig")[server_name].setup({
						capabilities = capabilities,
						settings = lsp_servers[server_name],
					})
				end,
			})
		end
	},

	{
		"jose-elias-alvarez/null-ls.nvim",
		config = function()
			require("null-ls").setup({
				sources = {
					require("null-ls").builtins.formatting.prettierd,
					require("null-ls").builtins.diagnostics.markdownlint,
				}
			})
		end
	},

	-- autocomplete
	{
		"hrsh7th/nvim-cmp",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"L3MON4D3/LuaSnip",
			"saadparwaiz1/cmp_luasnip",
			"hrsh7th/cmp-omni",
		},
		config = function()
			-- nvim-cmp setup
			local cmp = require("cmp")
			local luasnip = require("luasnip")

			luasnip.config.setup({
				enable_autosnippets = true,
			})

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				mapping = cmp.mapping.preset.insert({
					["<C-n>"] = cmp.mapping.select_next_item(),
					["<C-p>"] = cmp.mapping.select_prev_item(),
					["<C-d>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-Space>"] = cmp.mapping.complete({}),
					["<CR>"] = cmp.mapping.confirm({
						behavior = cmp.ConfirmBehavior.Replace,
						select = true,
					}),
					["<Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_next_item()
						elseif luasnip.expand_or_jumpable() then
							luasnip.expand_or_jump()
						else
							fallback()
						end
					end, { "i", "s" }),
					["<S-Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							cmp.select_prev_item()
						elseif luasnip.jumpable(-1) then
							luasnip.jump(-1)
						else
							fallback()
						end
					end, { "i", "s" }),
				}),
				sources = {
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "omni" },
				},
			})
		end

	},

	"gibiansky/vim-latex-objects",
}
