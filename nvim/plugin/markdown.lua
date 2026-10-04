-- the preview server is downloaded by the PackChanged hook in init.lua
vim.pack.add({ "https://github.com/iamcco/markdown-preview.nvim" })

-- see tools/viewer. the server calls this by name, so it must be vimscript
if vim.fn.executable("viewer") == 1 then
	vim.cmd([[
		function! MkdpViewer(url) abort
			call jobstart(['viewer', a:url], { 'detach': v:true })
		endfunction
	]])
	vim.g.mkdp_browserfunc = "MkdpViewer"
end
