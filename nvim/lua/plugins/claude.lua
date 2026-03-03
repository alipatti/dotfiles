return {
	"coder/claudecode.nvim",
	dependencies = { "akinsho/toggleterm.nvim" },
	config = function()
		local Terminal = require("toggleterm.terminal").Terminal
		local term = nil

		local function get_or_create_term(cmd_string, env_table, effective_config)
			if not term then
				term = Terminal:new({
					cmd = cmd_string,
					env = env_table,
					--  TODO: choose horizontal/vertical depending on available space
					direction = "vertical",
					hidden = true,
					close_on_exit = effective_config.auto_close,
					on_exit = function()
						term = nil
					end,
				})
			end
			return term
		end

		local function get_size(effective_config)
			return math.floor(vim.o.columns * (effective_config.split_width_percentage or 0.3))
		end

		require("claudecode").setup({
			terminal = {
				provider = {
					setup = function(_config)
						-- terminal is created lazily on first open
					end,

					open = function(cmd_string, env_table, effective_config, focus)
						if focus == nil then
							focus = true
						end

						local t = get_or_create_term(cmd_string, env_table, effective_config)
						if not t:is_open() then
							t:open(get_size(effective_config))
						end

						if focus then
							t:focus()
						end
					end,

					close = function()
						if term and term:is_open() then
							term:close()
						end
					end,

					simple_toggle = function(cmd_string, env_table, effective_config)
						local t = get_or_create_term(cmd_string, env_table, effective_config)
						if t:is_open() then
							t:close()
						else
							t:open(get_size(effective_config))
						end
					end,

					focus_toggle = function(cmd_string, env_table, effective_config)
						local t = get_or_create_term(cmd_string, env_table, effective_config)
						if not t:is_open() then
							t:open(get_size(effective_config))
							t:focus()
						elseif t:is_focused() then
							t:close()
						else
							t:focus()
						end
					end,

					get_active_bufnr = function()
						if term and term:is_open() then
							return term.bufnr
						end

						return nil
					end,

					is_available = function()
						return true
					end
				},
			},
		})
	end,
}
