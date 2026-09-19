-- open files from nested nvim instances (e.g. git commit in a terminal) in
-- the parent. loaded first so nested instances bail out early
vim.pack.add({ "https://github.com/willothy/flatten.nvim" })

require("flatten").setup({
	window = {
		open = "alternate",
	},
	hooks = {
		post_open = function(bufnr, winnr, ft, is_blocking)
			-- autocmd to close buffer on write if the file is a git commit
			if ft == "gitcommit" or ft == "gitrebase" then
				vim.api.nvim_create_autocmd("BufWritePost", {
					buffer = bufnr,
					once = true,
					callback = vim.schedule_wrap(function()
						vim.api.nvim_buf_delete(bufnr, {})
					end),
				})
			end
		end,
	}
})
