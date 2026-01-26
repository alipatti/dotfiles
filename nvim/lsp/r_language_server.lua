return {
	cmd       = { "R", "--slave", "-e", "languageserver::run()" },
	filetypes = { "r", "R", "Rmd", "rmd" },
	root_dir  = vim.fs.dirname(vim.fs.find({ '.git', 'DESCRIPTION' }, { upward = true })[1])
}
