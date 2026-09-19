-- the preview server is downloaded by the PackChanged hook in init.lua
vim.pack.add({ "https://github.com/iamcco/markdown-preview.nvim" })

-- see macos/webview.swift. the server calls this by name, so it must be vimscript
if vim.fn.executable("webview") == 1 then
	vim.cmd([[
		function! MkdpWebview(url) abort
			call jobstart(['webview', a:url], { 'detach': v:true })
		endfunction
	]])
	vim.g.mkdp_browserfunc = "MkdpWebview"
end
