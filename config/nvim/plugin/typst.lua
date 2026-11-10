-- fork that serves the page and its websocket on one port, so a preview over
-- ssh needs a single forward. switch back once it's merged upstream
vim.pack.add({
	{ src = "https://github.com/alipatti/typst-preview.nvim", version = "single-port" },
})

-- see apps/viewer
local viewer = vim.fn.executable("viewer") == 1

require("typst-preview").setup({
	dependencies_bin = { tinymist = "tinymist" },
	open_cmd = viewer and "viewer %s" or nil,
	-- offscreen pages are canvases in a foreignObject, which webkit misplaces
	partial_rendering = not viewer,
	get_root = function()
		return vim.fn.getcwd()
	end,
})

-- the preview only updates on TextChanged, which isn't fired when checktime
-- reloads a buffer that isn't current (e.g. after claude edits it)
vim.api.nvim_create_autocmd("FileChangedShellPost", {
	pattern = "*.typ",
	callback = function(ev)
		vim.api.nvim_exec_autocmds("TextChanged", { buffer = ev.buf })
	end,
})
