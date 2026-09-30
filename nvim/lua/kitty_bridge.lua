-- messages to the kitty watcher in tools/kitty_bridge.py. nvim writes them
-- to its own terminal as a user variable, so this also works over ssh, where
-- kitty's control socket can't be reached. fire and forget: no replies

local M = {}

-- set locally by fish and forwarded by `kitten ssh` (see kitty.nix)
local SECRET = vim.env.KITTY_BRIDGE_SECRET

M.available = vim.env.KITTY_WINDOW_ID ~= nil and SECRET ~= nil

function M.send(message)
	message.secret = SECRET
	message.pid = vim.fn.getpid()
	local value = vim.base64.encode(vim.json.encode(message))
	vim.api.nvim_ui_send(("\27]1337;SetUserVar=kitty_bridge=%s\7"):format(value))
end

return M
