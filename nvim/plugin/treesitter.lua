local required_grammars = {
	-- languages
	"python", "rust",
	"javascript", "typescript", "tsx", "svelte",
	"lua",

	-- markup
	"html", "markdown",
	"latex", "typst",

	-- data
	"json", "toml", "yaml",

	-- shell and config
	"fish",
	"dockerfile",

	-- git
	"gitcommit", "gitignore", "gitattributes",

	-- vim
	"vimdoc",
}

local function select_textobj(lhs, obj)
	local function rhs()
		local select = require("nvim-treesitter-textobjects.select")
		select.select_textobject(obj, "textobjects")
	end

	return { lhs, rhs, mode = { "x", "o" }, desc = "Select " .. obj }
end

local function next_textobj(lhs, obj)
	local function rhs()
		local move = require("nvim-treesitter-textobjects.move")
		move.goto_next_start(obj, "textobjects")
	end

	return { lhs, rhs, desc = "Next " .. obj }
end

local function prev_textobj(lhs, obj)
	local function rhs()
		local move = require("nvim-treesitter-textobjects.move")
		move.goto_previous_start(obj, "textobjects")
	end

	return { lhs, rhs, desc = "Previous " .. obj }
end

vim.pack.add({
	"https://github.com/nvim-treesitter/nvim-treesitter",
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "main" },
})

-- parsers are updated by the PackChanged hook in init.lua
require("nvim-treesitter").setup()
require("nvim-treesitter").install(required_grammars)

require("nvim-treesitter-textobjects").setup({
	select = { lookahead = true },
	move = { set_jumps = true },
})

local keys = {
	-- builtin incremental selection (:help treesitter-incremental-selection)
	{ "<C-k>", "van", mode = "n", remap = true, desc = "Expand selection" },
	{ "<C-k>", "an",  mode = "x", remap = true, desc = "Expand selection" },
	{ "<C-j>", "in",  mode = "x", remap = true, desc = "Contract selection" },

	select_textobj("aa", "@parameter.outer"),
	select_textobj("ia", "@parameter.inner"),
	select_textobj("af", "@function.outer"),
	select_textobj("if", "@function.inner"),
	select_textobj("ac", "@class.outer"),
	select_textobj("ic", "@class.inner"),
	next_textobj("]]", "@function.outer"),
	prev_textobj("[[", "@function.outer"),
}

for _, key in ipairs(keys) do
	vim.keymap.set(key.mode or "n", key[1], key[2], { desc = key.desc, remap = key.remap, silent = true })
end
