-- open files from nested nvim instances (e.g. git commit in a terminal) in
-- the parent. loaded first so nested instances bail out early
vim.pack.add({ "https://github.com/willothy/flatten.nvim" })

-- guests can also come from sibling kitty windows (see kitty.lua), where
-- opening a file should bring nvim to the front and unblocking should go back
local function kitty_focus(guest, target)
	if vim.env.KITTY_LISTEN_ON and guest and guest ~= vim.env.KITTY_WINDOW_ID then
		vim.system({ "kitten", "@", "focus-window", "--match", "id:" .. target })
	end
end

require("flatten").setup({
	window = {
		open = "alternate",
	},
	hooks = {
		-- runs in the guest
		guest_data = function()
			return { kitty_window = vim.env.KITTY_WINDOW_ID }
		end,
		post_open = function(opts)
			kitty_focus(opts.data and opts.data.kitty_window, vim.env.KITTY_WINDOW_ID)

			-- autocmd to close buffer on write if the file is a git commit
			if opts.filetype == "gitcommit" or opts.filetype == "gitrebase" then
				vim.api.nvim_create_autocmd("BufWritePost", {
					buffer = opts.bufnr,
					once = true,
					callback = vim.schedule_wrap(function()
						vim.api.nvim_buf_delete(opts.bufnr, {})
					end),
				})
			end
		end,
		block_end = function(opts)
			local guest = opts.data and opts.data.kitty_window
			kitty_focus(guest, guest)
		end,
	},
})
