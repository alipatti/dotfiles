if not vim.env.KITTY_LISTEN_ON then
	return -- not inside kitty
end

-- each window we launch is tagged with these env vars, so it can be found
-- again from nvim (env: match) and can identify itself from the inside
local ROLE_VAR = "NVIM_TERM_ROLE"
local PARENT_VAR = "NVIM_TERM_PARENT"

-- <send><target>{motion} sends text, e.g. stip or scaf. the uppercase send
-- key is the linewise version, like d/D and c/C: St, Sc
-- <focus><target> focuses the window, launching it if needed
local SEND = "s"
local FOCUS = "t"

local pid = vim.fn.getpid()

local function kitty(args, stdin)
	local cmd = vim.list_extend({ "kitten", "@" }, args)
	return vim.system(cmd, { stdin = stdin, text = true }):wait()
end

local function match(role)
	return string.format("env:%s=^%s$ and env:%s=^%d$", ROLE_VAR, role, PARENT_VAR, pid)
end

local function exists(role)
	local res = kitty({ "ls", "--match", match(role) })
	if res.code ~= 0 then
		return false
	end
	local ok, tree = pcall(vim.json.decode, res.stdout)
	return ok and #tree > 0
end

-- make sure the window for `role` exists. returns true if it was just created
local function ensure(role, cmd, keep_focus)
	if exists(role) then
		return false
	end
	local args = {
		"launch",
		"--type=window",
		"--location=last",
		"--cwd=" .. vim.fn.getcwd(),
		"--title=" .. role,
		"--env=" .. ROLE_VAR .. "=" .. role,
		"--env=" .. PARENT_VAR .. "=" .. pid,
		-- same var nvim sets in :terminal. lets flatten open files from these
		-- windows in this nvim, and lets claude's hook run checktime
		"--env=NVIM=" .. vim.v.servername,
	}
	if keep_focus then
		table.insert(args, "--keep-focus")
	end
	local res = kitty(vim.list_extend(args, cmd or {}))
	if res.code ~= 0 then
		vim.notify("kitty launch failed: " .. res.stderr, vim.log.levels.ERROR)
	end
	return true
end

-- unzoom so the terminals are visible next to nvim
local function show()
	kitty({ "goto-layout", "tall" })
end

local function focus(role, cmd)
	show()
	if not ensure(role, cmd, false) then
		kitty({ "focus-window", "--match", match(role) })
	end
end

-- paste `text` into the target's window, creating it if needed
local function send(target, text)
	show()
	ensure(target.role, target.cmd, true)
	local args = { "send-text", "--match", match(target.role), "--stdin" }
	-- bracketed paste keeps multiline text in one piece; the newline that runs
	-- it has to come after the paste ends
	kitty(vim.list_extend(vim.list_slice(args), { "--bracketed-paste=auto" }), text)
	if target.submit then
		kitty(args, "\r")
	end
end

local region_type = { line = "V", char = "v", block = "\22" }

local function send_region(target)
	return function(motion_type)
		local lines = vim.fn.getregion(vim.fn.getpos("'["), vim.fn.getpos("']"), { type = region_type[motion_type] })
		send(target, table.concat(lines, "\n"))
	end
end

-- terminals die with vim
vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		local m = string.format("env:%s=^%d$", PARENT_VAR, pid)
		kitty({ "close-window", "--ignore-no-match", "--match", m })
	end,
})

-- drop the builtin keymaps
vim.keymap.set({ "n", "x" }, SEND, "<Nop>")
vim.keymap.set({ "n", "x" }, string.upper(SEND), "<Nop>")

-- terminals to create
local targets = {
	{ key = "t", role = "terminal", submit = true,       advance = true },
	{ key = "p", role = "ipython",  cmd = { "uv", "run", "--with", "ipython", "ipython" }, submit = true, advance = true },
	{ key = "c", role = "claude",   cmd = { "claude" } },
}

local function set_opfunc(fn)
	_G._kitty_opfunc = fn
	vim.o.operatorfunc = "v:lua._kitty_opfunc"
end

for _, target in ipairs(targets) do
	vim.keymap.set("n", FOCUS .. target.key, function()
		focus(target.role, target.cmd)
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

