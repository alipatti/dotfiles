local claude_term = {}
local main_term = {}

local function term_size()
	if vim.o.columns > 150 then
		return 80, "vertical"
	else
		return 20, "horizontal"
	end
end

local function focus_or_toggle(term_ref, opts)
	local size, direction = term_size()

	if not term_ref[1] then
		local Terminal = require("toggleterm.terminal").Terminal
		term_ref[1] = Terminal:new(vim.tbl_extend("keep", opts, {
			direction = opts.direction or direction,
			hidden = true,
			close_on_exit = true,
			on_exit = function()
				term_ref[1] = nil
			end,
		}))
	end

	local term = term_ref[1]
	if not term:is_open() then
		term:open(size)
		term:focus()
	elseif term:is_focused() then
		term:close()
	else
		term:focus()
	end
end

local function set_opfunc(fn)
	_G._toggleterm_opfunc = fn
	vim.o.operatorfunc = "v:lua._toggleterm_opfunc"
end

local function send_ref_to_claude(start_line, end_line)
	local filename = vim.fn.expand("%")
	local ref = start_line == end_line
			and string.format("@%s:%d", filename, start_line)
			or string.format("@%s:%d-%d", filename, start_line, end_line)
	require("toggleterm").exec(ref, 88)
end

return {
	{
		'akinsho/toggleterm.nvim',
		version = "*",
		opts = {
			float_opts = { border = "curved" }
		},
		keys = {
			{
				"<leader>c",
				function()
					focus_or_toggle(claude_term, { count = 88, cmd = "claude",
					})
				end,
				desc = "Toggle Claude",
			},
			{
				"<leader>t",
				function()
					focus_or_toggle(main_term, { count = 99 })
				end,
				desc = "Toggle terminal",
			},
			{
				"<esc>",
				[[<C-\><C-n><C-w><C-w>]],
				desc = "Leave terminal mode",
				mode = "t"
			},
			-- TERMINAL --
			{
				"L",
				function()
					set_opfunc(function(motion_type)
						require("toggleterm").send_lines_to_terminal(motion_type, true, { args = 99 })
					end)
					return "g@"
				end,
				desc = "Send motion to terminal",
				expr = true,
			},
			{
				"LL",
				function()
					require("toggleterm").send_lines_to_terminal("single_line", true, { args = 99 })
					vim.cmd("normal! j")
				end,
				desc = "Send line to terminal",
			},
			{
				"L",
				function()
					require("toggleterm").send_lines_to_terminal("visual_selection", true, { args = 99 })
				end,
				desc = "Send selection to terminal",
				mode = "x",
			},
			-- CLAUDE --
			{
				"K",
				function()
					set_opfunc(function(_)
						send_ref_to_claude(vim.fn.line("'["), vim.fn.line("']"))
					end)
					return "g@"
				end,
				desc = "Send motion to Claude",
				expr = true,
			},
			{
				"KK",
				function()
					send_ref_to_claude(vim.fn.line("."), vim.fn.line("."))
				end,
				desc = "Send line to Claude",
			},
			{
				"K",
				function()
					send_ref_to_claude(vim.fn.line("'<"), vim.fn.line("'>"))
				end,
				desc = "Send selection to Claude",
				mode = "x",
			},
		}
	},
}
