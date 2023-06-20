return {
	{
		"nvim-lualine/lualine.nvim",
		opts = {
			options = {
				component_separators = "|",
				section_separators = { left = '', right = '' },
				globalstatus = true,
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "filename", "branch" },
				lualine_c = {},
				lualine_x = {},
				lualine_y = { "filetype", "progress" },
				lualine_z = { "location" },
			},
			tabline = {
				lualine_a = { "buffers" },
				lualine_b = {},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
				lualine_z = { "datetime" },
			},
		},
	},
}
