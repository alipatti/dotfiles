local function floating_win_config()
	local w = 50
	local h = 50
	local ui = vim.api.nvim_list_uis()[1]

	return {
		relative = "editor",
		border = "rounded",
		style = "minimal",
		width = w,
		height = h,
		row = (ui.height / 2) - (h / 2),
		col = (ui.width / 2) - (w / 2),
	}
end

return {
	-- file tree
	{
		"nvim-tree/nvim-tree.lua",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
		opts = {
			sync_root_with_cwd = true,
			view = {
				float = {
					enable = true,
					open_win_config = floating_win_config(),
				},
			},
			on_attach = function(bufnr)
				-- use default on_attach function
				local api = require("nvim-tree.api")
				api.config.mappings.default_on_attach(bufnr)

				-- set colors
				vim.cmd("highlight NvimTreeNormal guibg=Normal")
				vim.cmd("highlight NvimTreeEndOfBuffer guibg=Normal")
				vim.cmd("highlight FloatBorder guibg=Normal")

				-- set key bindings
				vim.keymap.set("n", "<esc>", api.tree.close)
				vim.keymap.set("n", "<C-c>", api.tree.close)
			end,
		},
		lazy = false,
		keys = {
			{ "<leader>f", "<cmd>NvimTreeToggle<cr>", desc = "Open file tree" },
		}
	},
}
