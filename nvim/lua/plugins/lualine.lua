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


local get_word_count = function()
	if
	    vim.bo.filetype == "md"
	    or vim.bo.filetype == "txt"
	    or vim.bo.filetype == "markdown"
	    or vim.bo.filetype == "tex"
	then
		if vim.fn.wordcount().visual_words == 1 then
			return tostring(vim.fn.wordcount().visual_words) .. " word"
		elseif not (vim.fn.wordcount().visual_words == nil) then
			return tostring(vim.fn.wordcount().visual_words) .. " words"
		else
			return tostring(vim.fn.wordcount().words) .. " words"
		end
	else
		return ""
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
				lualine_b = { "filename" },
				lualine_c = {
					{ "diff",        source = get_diff },
					"diagnostics",
					{ get_word_count },
				},
				lualine_x = {},
				lualine_y = { "location", "progress" },
				lualine_z = { "filetype" },
			},
			tabline = {
				lualine_a = { { "tabs", mode = 2 } },
				lualine_b = {},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
				lualine_z = { "buffers" },
			},
		},
	},
}
