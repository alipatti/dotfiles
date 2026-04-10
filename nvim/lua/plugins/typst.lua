return {
	'chomosuke/typst-preview.nvim',
	ft = 'typst',
	version = '1.*',
	opts = {
		dependencies_bin = { tinymist = 'tinymist' },
		get_root = function()
			return vim.fn.getcwd()
		end,
	},
}
