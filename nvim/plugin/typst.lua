vim.pack.add({
	{ src = "https://github.com/chomosuke/typst-preview.nvim", version = vim.version.range("1") },
})

require("typst-preview").setup({
	dependencies_bin = { tinymist = "tinymist" },
	get_root = function()
		return vim.fn.getcwd()
	end,
})
