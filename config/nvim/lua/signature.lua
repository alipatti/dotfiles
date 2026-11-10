-- signature help that cycles: signature only, then with docs, then closed
local sig_ns = vim.api.nvim_create_namespace("signature_help")
local sig_win, sig_docs

local function signature_help()
	if sig_win and vim.api.nvim_win_is_valid(sig_win) then
		if sig_docs then
			vim.api.nvim_win_close(sig_win, true)
			return
		end
		sig_docs = true
	else
		sig_docs = false
	end

	vim.lsp.buf_request_all(0, "textDocument/signatureHelp", function(client)
		return vim.lsp.util.make_position_params(0, client.offset_encoding)
	end, function(results, ctx)
		for client_id, r in pairs(results) do
			local result = r.result
			if result and result.signatures and #result.signatures > 0 then
				if not sig_docs then
					for _, sig in ipairs(result.signatures) do
						sig.documentation = nil
						for _, param in ipairs(sig.parameters or {}) do
							param.documentation = nil
						end
					end
				end
				local client = assert(vim.lsp.get_client_by_id(client_id))
				local triggers = vim.tbl_get(
					client.server_capabilities,
					"signatureHelpProvider",
					"triggerCharacters"
				)
				local lines, hl = vim.lsp.util.convert_signature_help_to_markdown_lines(
					result,
					vim.bo[ctx.bufnr].filetype,
					triggers
				)
				-- replaces any existing preview float for this buffer
				local buf, win = vim.lsp.util.open_floating_preview(assert(lines), "markdown", { focus = false })
				if hl then
					vim.hl.range(buf, sig_ns, "LspSignatureActiveParameter", { hl[1], hl[2] }, { hl[3], hl[4] })
				end
				sig_win = win
				return
			end
		end
	end)
end

return signature_help
