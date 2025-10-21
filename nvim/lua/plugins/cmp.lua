return {
	-- autocomplete
	{
		"hrsh7th/nvim-cmp",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"L3MON4D3/LuaSnip",
			"saadparwaiz1/cmp_luasnip",
			"jmbuhr/otter.nvim",
			"hrsh7th/cmp-path",
			"davidsierradz/cmp-conventionalcommits",
			"petertriho/cmp-git", -- reference issues, people, etc.
		},
		config = function()
			-- load snippet enginge
			local luasnip = require("luasnip")
			luasnip.config.setup({
				enable_autosnippets = true,
			})
			require("luasnip.loaders.from_lua")
				.load({ paths = "~/.config/nvim/snippets/" })

			-- nvim-cmp setup
			local cmp = require("cmp")
			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				mapping = cmp.mapping.preset.insert({
					["<C-n>"] = cmp.mapping.select_next_item(),
					["<C-p>"] = cmp.mapping.select_prev_item(),
					['<C-c>'] = cmp.mapping.abort(),
					["<C-d>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-Space>"] = cmp.mapping.confirm({ select = true }),
					["<tab>"] = cmp.mapping.confirm({ select = true }),
				}),
				sources = {
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "otter" }, -- for quarto
					{ name = "git" },
					{ name = "conventionalcommits" },
					{
						name = "path",
						option = { get_cwd = function() return vim.fn.getcwd() end }
					},
				},
			})

			-- clear tabstops when i exit insert mode
			vim.api.nvim_create_autocmd("ModeChanged", {
				pattern = { "i:*" },
				callback = function()
					local ls = require("luasnip")
					if ls.in_snippet() then
						ls.unlink_current()
					end
				end,
			})
		end

	},

	{ "petertriho/cmp-git", opts = {} }

}
