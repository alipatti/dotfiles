local get_diff = function()
	---@diagnostic disable-next-line: undefined-field
	local gitsigns = vim.b.gitsigns_status_dict
	if gitsigns then
		return {
			added = gitsigns.added,
			modified = gitsigns.changed,
			removed = gitsigns.removed
		}
	end
end

return {
	{
		"nvim-lualine/lualine.nvim",
		opts = {
			options = {
				component_separators = "|",
				section_separators = { left = '', right = '' },
				-- globalstatus = true,
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "filename"},
				lualine_c = {
					{ "diff", source = get_diff },
					"diagnostics",
				},
				lualine_x = {},
				lualine_y = { "location", "progress" },
				lualine_z = { "filetype" },
			},
			tabline = {
				lualine_a = { "tabs" },
				lualine_b = {},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
				lualine_z = { "buffers" },
			},
		},
	},
}
