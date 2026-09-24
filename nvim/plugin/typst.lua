vim.pack.add({
	{ src = "https://github.com/chomosuke/typst-preview.nvim", version = vim.version.range("1") },
})

-- see tools/webview.swift
local webview = vim.fn.executable("webview") == 1

require("typst-preview").setup({
	dependencies_bin = { tinymist = "tinymist" },
	-- anything on stderr is reported as a failure
	open_cmd = webview and "webview %s 2>/dev/null" or nil,
	-- offscreen pages are canvases in a foreignObject, which webkit misplaces
	partial_rendering = not webview,
	get_root = function()
		return vim.fn.getcwd()
	end,
})
