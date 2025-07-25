return {
	{
		"willothy/flatten.nvim",
		opts = {
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
		},
		lazy = false,
		priority = 1001,
	},
}
