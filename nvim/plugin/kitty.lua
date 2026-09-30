local bridge = require("kitty_bridge")
if not bridge.available then
	return -- not inside kitty
end

-- each window we launch gets these env vars, so it can identify itself from
-- the inside. the watcher tags it with user vars to find it again
local ROLE_VAR = "NVIM_TERM_ROLE"
local PARENT_VAR = "NVIM_TERM_PARENT"

-- <send><target>{motion} sends text, e.g. stip or scaf. the uppercase send
-- key is the linewise version, like d/D and c/C: St, Sc
-- <focus><target> focuses the window, launching it if needed
local SEND = "s"
local FOCUS = "t"

-- open the window for `target` on nvim's host, unzooming and picking the
-- layout for the tab's width. with `text`, paste it there without focusing
local function open(target, text)
	bridge.send({
		op = "open",
		role = target.role,
		cmd = target.cmd,
		cwd = vim.fn.getcwd(),
		env = {
			[ROLE_VAR] = target.role,
			[PARENT_VAR] = tostring(vim.fn.getpid()),
			-- same var nvim sets in :terminal. lets flatten open files from these
			-- windows in this nvim, and lets claude's hook run checktime
			NVIM = vim.v.servername,
		},
		text = text,
		submit = target.submit,
	})
end

local region_type = { line = "V", char = "v", block = "\22" }

local function send_region(target)
	return function(motion_type)
		local lines = vim.fn.getregion(vim.fn.getpos("'["), vim.fn.getpos("']"), { type = region_type[motion_type] })
		open(target, table.concat(lines, "\n"))
	end
end

-- terminals die with vim
vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		bridge.send({ op = "close" })
	end,
})

-- drop the builtin keymaps
vim.keymap.set({ "n", "x" }, SEND, "<Nop>")
vim.keymap.set({ "n", "x" }, string.upper(SEND), "<Nop>")

-- the dataframe browser is macos only (appkit)
local ipython = { "uv", "run", "--with", "ipython", "ipython" }
if vim.fn.has("mac") == 1 then
	table.insert(ipython, 5, "--with")
	table.insert(ipython, 6, "git+https://github.com/alipatti/browse@8d18aafae82404edaa363d3f20324c8fae5c2968")
end

-- terminals to create
local targets = {
	{ key = "t", role = "terminal", submit = true,       advance = true },
	{ key = "p", role = "ipython",  cmd = ipython,       submit = true, advance = true },
	{ key = "c", role = "claude",   cmd = { "claude" } },
}

local function set_opfunc(fn)
	_G._kitty_opfunc = fn
	vim.o.operatorfunc = "v:lua._kitty_opfunc"
end

for _, target in ipairs(targets) do
	vim.keymap.set("n", FOCUS .. target.key, function()
		open(target)
	end, { desc = "Focus " .. target.role })

	vim.keymap.set({ "n", "x" }, SEND .. target.key, function()
		set_opfunc(send_region(target))
		return "g@"
	end, { desc = "Send motion/selection to " .. target.role, expr = true })

	vim.keymap.set("n", string.upper(SEND) .. target.key, function()
		set_opfunc(send_region(target))
		vim.cmd("normal! g@_")
		if target.advance then
			vim.cmd("normal! j")
		end
	end, { desc = "Send line to " .. target.role })
end

