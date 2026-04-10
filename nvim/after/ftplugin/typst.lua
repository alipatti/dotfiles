local hl = vim.api.nvim_get_hl(0, { name = "@markup.heading", link = false })
hl.underline = true
hl.bold = true

vim.api.nvim_set_hl(0, "@markup.heading", hl)
