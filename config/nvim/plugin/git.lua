-- adds git releated signs to the gutter, as well as utilities for managing changes
vim.pack.add({ "https://github.com/lewis6991/gitsigns.nvim" })

require("gitsigns").setup({
	numhl               = false,
	signcolumn          = true,
	attach_to_untracked = true,
})

local keys = {
	{ "<leader>gh", "<cmd>Gitsigns preview_hunk_inline<cr>",                           desc = "diff hunk (inline)" },
	{ "<leader>gr", "<cmd>Gitsigns reset_hunk<cr>",                                    desc = "reset hunk" },
	{ "<leader>gb", "<cmd>Gitsigns toggle_current_line_blame<cr>",                     desc = "toggle blame" },
	{ "<leader>gd", "<cmd>Gitsigns toggle_linehl<cr><cmd>Gitsigns toggle_deleted<cr>", desc = "diff file (side-by-side)" },
	{ "<leader>gD", "<cmd>Gitsigns diffthis<cr><cmd>vertical wincmd h<cr>",            desc = "diff file (side-by-side)" },
}

for _, key in ipairs(keys) do
	vim.keymap.set("n", key[1], key[2], { desc = key.desc })
end
