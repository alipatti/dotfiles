local wk = require("which-key")

-- register leader keymaps
wk.register({
	s = {
		name = "Search...",
		s = { "<cmd>Telescope live_grep theme=dropdown<cr>", "grep current folder" },
		c = { "<cmd>Telescope current_buffer_fuzzy_find theme=dropdown previewer=false winblend=10<cr>",
			"within current buffer" },
		o = { "<cmd>Telescope buffers theme=dropdown previewer=false<cr>", "open buffers" },
		r = { "<cmd>Telescope recent theme=dropdown<cr>", "recent buffers" },
		g = { "<cmd>Telescope git_status<cr>", "git changes" },
		h = { "<cmd>Telescope help_tags<cr>", "help" },
	},
	l = {
		name = "LSP...",
		f = { vim.lsp.buf.format, "format buffer" },
		d = { vim.lsp.buf.definition, "go to definition" },
		D = { vim.lsp.buf.declaration, "go to declaration" },
		i = { vim.lsp.buf.implementation, "go to implementation" },
		t = { vim.lsp.buf.type_definition, "go to type definition" },
		r = { "<cmd>Telescope lsp_references theme=dropdown<cr>", "go to references" },
		R = { vim.lsp.buf.rename, "rename symbol" },
		a = { vim.lsp.buf.code_action, "code actions" },
		h = { vim.lsp.buf.hover, "hover" },
		s = { "<cmd>Telescope lsp_document_symbols<cr>", "search document symbols" },
		S = { "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", "search workspace symbols" },
		w = {
			name = "workspace...",
			a = { vim.lsp.buf.add_workspace_folder, "add folder" },
			r = { vim.lsp.buf.remove_workspace_folder, "remove folder" },
			l = { function()
				print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
			end, "list folders" },
		}
	},
	f = {
		name = "Files...",
		f = { "<cmd>NvimTreeToggle<cr>", "Open file tree" },
		w = { "<cmd>w<cr>", "Write buffer" },
		W = { "<cmd>wa<cr>", "Write all buffers" },
	},
	d = {
		name = "Diagnostics...",
		h = { vim.diagnostic.open_float, "Hover diagnostic" },
		l = { "<cmd>Telescope diagnostics theme=dropdown<cr>", "List diagnostics" },
	},
	t = {
		name = "Terminal...",
		t = { "<cmd>ToggleTerm direction=float<cr>", "Toggle floating terminal" },
	},
	b = {
		name = "Buffer...",
		n = { "<cmd>bn<cr>", "Next" },
		p = { "<cmd>bp<cr>", "Previous" },
		d = { "<cmd>bd<cr>", "Delete" },
	}
}, { mode = 'n', prefix = '<leader>' })

-- insert mode keymaps
wk.register({
	["<C-i>"] = { vim.lsp.buf.signature_help, "function signature help" },
	["<C-h>"] = { "<Left>", "go left" },
	["<C-l>"] = { "<Right>", "go right" },
}, { mode = "i" })

-- normal mode keymaps
wk.register({
	["[d"] = { vim.diagnostic.goto_next, "Go to previous diagnostic message" },
	["]d"] = { vim.diagnostic.goto_next, "Go to next diagnostic message" },
	U = { "<cmd>redo<cr>", "Redo" },
}, { mode = "n" })

-- Remap for dealing with word wrap
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", {
	expr = true,
	silent = true,
})
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", {
	expr = true,
	silent = true,
})
