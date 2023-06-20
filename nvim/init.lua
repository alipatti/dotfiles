-- alipatti's nvim configuration

-- TODO:
-- - add akinsho/toggleterm.nvim
-- - add keymaps for creating a new file, editing a specific file, etc.
-- - add keymaps for git (blame, hunk-related, etc.)

-- set leader
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-------------
-- PLUGINS --
-------------

-- use lazy.nvim as the package manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")

-------------
-- KEYMAPS --
-------------

require("keymaps")
require("highlight-on-yank")

----------
-- MISC --
----------

-- highlight on search
vim.o.hlsearch = false

-- make line numbers default
vim.wo.number = true

-- enable mouse mode
vim.o.mouse = "a"

-- sync clipboard between OS and Neovim.
vim.o.clipboard = "unnamedplus"

-- enable break indent
vim.o.breakindent = true

-- save undo history
vim.o.undofile = true

-- case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- keep signcolumn on by default
vim.wo.signcolumn = "yes"

-- decrease update time
vim.o.updatetime = 250
vim.o.timeout = true
vim.o.timeoutlen = 300

-- set completeopt to have a better completion experience
vim.o.completeopt = "menuone,noselect" -- use full terminal colors
vim.o.termguicolors = true

-- use natural line wrapping
vim.wo.wrap = "linebreak"
vim.opt.linebreak = true

-- LSPs to be installed
local servers = {
	-- TODO: figure out why this isn't working
	-- python
	-- pyright = {},
	--
	-- -- rust
	-- rust_analyzer = {},
	-- -- rustfmt = {},
	--
	-- -- web development
	-- html = {},
	-- cssls = {},
	-- emmet_ls = {},
}

-- TODO: move to lua/plugins/lsp.lua

-- setup neovim lua configuration
require("neodev").setup()

-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

require("mason-lspconfig").setup({
	ensure_installed = vim.tbl_keys(servers),
})

require("mason-lspconfig").setup_handlers({
	function(server_name)
		require("lspconfig")[server_name].setup({
			capabilities = capabilities,
			settings = servers[server_name],
		})
	end,
})

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

-- load snippets from external file
require("luasnip.loaders.from_lua").load({ paths = "~/.config/nvim/snippets/" })

-- set color scheme
-- TODO: set color scheme to change with system settings?
-- TODO: add keyboard shortcut to toggle color scheme
vim.cmd.colorscheme("catppuccin")
