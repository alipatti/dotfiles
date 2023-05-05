-- alipatti's nvim configuration

-- use lazy.nvim as the package manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- load packages
require("lazy").setup({
  "sainnhe/everforest", -- color theme

  "tpope/vim-fugitive", -- git support
  "tpope/vim-sleuth",   -- automatically detect indentation
  "tpope/vim-surround", -- surround with quotes, parens, tags, etc.
  "lervag/vimtex",      -- latex plugin

  {
    "folke/todo-comments.nvim",
    opts = {},
    dependencies = { "nvim-lua/plenary.nvim" }
  }, -- highlight todo comments

  -- file tree
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      sync_root_with_cwd = true,
      view = {
        float = {
          enable = true,
          open_win_config = {
            relative = "editor",
            border = "rounded",
            style = "minimal",
            width = 30,
            height = 30,
            row = 1,
            col = 1,
          }
        }
      },
      on_attach = function(bufnr)
        -- use default on_attach function
        local api = require('nvim-tree.api')
        api.config.mappings.default_on_attach(bufnr)

        -- set colors
        vim.cmd("highlight NvimTreeNormal guibg=Normal")
        vim.cmd("highlight NvimTreeEndOfBuffer guibg=Normal")
        vim.cmd("highlight FloatBorder guibg=Normal")

        -- set key bindings
        vim.keymap.set("n", "<esc>", api.tree.close)
        vim.keymap.set("n", "<C-c>", api.tree.close)
      end
    },
  },

  -- LSP plugins and config
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      {
        -- package to manage lsps, formatters, etc.
        "williamboman/mason.nvim",
        config = true,
      },
      "williamboman/mason-lspconfig.nvim",
      {
        "j-hui/fidget.nvim",
        opts = {},
      },

      "folke/neodev.nvim", -- autocomplete, etc. for lua config
    },
  },

  -- autocomplete
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "hrsh7th/cmp-omni",
    },
  },

  -- shows pending keybinds
  {
    "folke/which-key.nvim",
    opts = {},
  },
  {
    -- adds git releated signs to the gutter, as well as utilities for managing changes
    "lewis6991/gitsigns.nvim",
    opts = {
      -- See `:help gitsigns.txt`
      signs = {
        add = {
          text = "+",
        },
        change = {
          text = "~",
        },
        delete = {
          text = "_",
        },
        topdelete = {
          text = "‾",
        },
        changedelete = {
          text = "~",
        },
      },
    },
  },

  -- statusline
  {
    "nvim-lualine/lualine.nvim",
    opts = {
      options = {
        icons_enabled = false,
        component_separators = "|",
        section_separators = "",
        globalstatus = true,
      },
    },
  },

  -- Add indentation guides even on blank lines
  {
    "lukas-reineke/indent-blankline.nvim",
    -- Enable `lukas-reineke/indent-blankline.nvim`
    -- See `:help indent_blankline.txt`
    opts = {
      show_trailing_blankline_indent = false,
      show_current_context_start = true,
    },
  },

  -- "gc" to comment visual regions/lines
  {
    "numToStr/Comment.nvim",
    opts = {},
  },

  -- search within files, bufers, symbols, etc
  {
    "nvim-telescope/telescope.nvim",
    version = "*",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    cond = function()
      return vim.fn.executable("make") == 1
    end,
  },

  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" }
  },

  {
    -- syntax highlighting, document parsing, etc.
    "nvim-treesitter/nvim-treesitter",
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    build = ":TSUpdate",
  },

}, {})


-- highlight on search
vim.o.hlsearch = false

-- make line numbers default
vim.wo.number = true

-- enable mouse mode
vim.o.mouse = "a"

-- sync clipboard between OS and Neovim.
vim.o.clipboard = "unnamedplus"

-- enable break indent
vim.o.breakindent = true

-- save undo history
vim.o.undofile = true

-- case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- keep signcolumn on by default
vim.wo.signcolumn = "yes"

-- decrease update time
vim.o.updatetime = 250
vim.o.timeout = true
vim.o.timeoutlen = 300

-- set completeopt to have a better completion experience
vim.o.completeopt = "menuone,noselect"

-- use full terminal colors
vim.o.termguicolors = true

-- use natural line wrapping
vim.wo.wrap = "linebreak"
vim.opt.linebreak = true

-------------
-- KEYMAPS --
-------------

-- Set <space> as the leader key
-- See `:help mapleader`
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- disable space bar so we can use it as the leader
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", {
  silent = true,
})

-- toggle file tree
vim.keymap.set("n", "f", require("nvim-tree.api").tree.toggle)

-- Remap for dealing with word wrap
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", {
  expr = true,
  silent = true,
})
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", {
  expr = true,
  silent = true,
})

-- redo
vim.keymap.set("n", "U", ":redo<CR>")

-- moving left/right while in insert mode
vim.keymap.set("i", "<C-l>", "<Right>")
vim.keymap.set("i", "<C-h>", "<Left>")

-----------------------
-- HIGHLIGHT ON YANK --
-----------------------

local highlight_group = vim.api.nvim_create_augroup("YankHighlight", {
  clear = true,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = "*",
})

-----------------------------
-- TELESCOPE CONFIGURATION --
-----------------------------

require("telescope").setup({
  defaults = {
    mappings = {
      i = {
        ["<C-u>"] = false,
        ["<C-d>"] = false,
      },
    },
  },
})

-- enable fuzzy finding if installed
pcall(require("telescope").load_extension, "fzf")

-- search inside file
vim.keymap.set("n", "<leader>/", function()
  require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
    winblend = 10,
    previewer = false,
  }))
end, {
  desc = "[/] Search in current buffer",
})

-- search recent files
vim.keymap.set("n", "<leader>sr", require("telescope.builtin").oldfiles, {
  desc = "[S]earch [r]ecently opened files",
})

-- search open files
vim.keymap.set("n", "<leader>so", require("telescope.builtin").buffers, {
  desc = "[S]earch [o]pen buffers",
})

-- search all files
vim.keymap.set("n", "<leader>sf", require("telescope.builtin").find_files, {
  desc = "[S]earch [f]iles",
})

-- search help
vim.keymap.set("n", "<leader>sh", require("telescope.builtin").help_tags, {
  desc = "[S]earch [h]elp",
})

-- search via grep
vim.keymap.set("n", "<leader>sg", require("telescope.builtin").live_grep, {
  desc = "[S]earch by [g]rep",
})

-- search diagnostics
vim.keymap.set("n", "<leader>sd", require("telescope.builtin").diagnostics, {
  desc = "[S]earch [d]iagnostics",
})

require("nvim-treesitter.configs").setup({
  -- languages to be installed
  ensure_installed = {
    "lua",
    "python",
    "rust",
    "javascript",
    "tsx",
    "typescript",
    "vimdoc",
    "vim",
    "latex",
    "r",
  },

  -- add uninstalled languages automatically
  auto_install = true,

  highlight = {
    enable = true,
    disable = { "latex" }
  },

  indent = {
    enable = true,
    disable = { "python" },
  },

  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "<C-k>",
      node_incremental = "<C-k>",
      -- scope_incremental = "<C-s>",
      node_decremental = "<C-j>",
    },
  },

  -- TODO: figure out what this does
  textobjects = {
    select = {
      enable = true,
      lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
      keymaps = {
        -- You can use the capture groups defined in textobjects.scm
        ["aa"] = "@parameter.outer",
        ["ia"] = "@parameter.inner",
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
      },
    },
    move = {
      enable = true,
      set_jumps = true, -- whether to set jumps in the jumplist
      goto_next_start = {
        ["]m"] = "@function.outer",
        ["]]"] = "@class.outer",
      },
      goto_next_end = {
        ["]M"] = "@function.outer",
        ["]["] = "@class.outer",
      },
      goto_previous_start = {
        ["[m"] = "@function.outer",
        ["[["] = "@class.outer",
      },
      goto_previous_end = {
        ["[M"] = "@function.outer",
        ["[]"] = "@class.outer",
      },
    },
    swap = {
      enable = true,
      swap_next = {
        ["<leader>a"] = "@parameter.inner",
      },
      swap_previous = {
        ["<leader>A"] = "@parameter.inner",
      },
    },
  },
})

-- Diagnostic keymaps
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, {
  desc = "Go to previous diagnostic message",
})
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, {
  desc = "Go to next diagnostic message",
})
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, {
  desc = "Open floating diagnostic message",
})
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, {
  desc = "Open diagnostics list",
})

--  this function gets run when an LSP connects to a particular buffer.
local on_attach = function(_, bufnr)
  -- a function that lets us more easily define mappings specific
  -- for LSP related items
  local lspmap = function(keys, func, desc)
    if desc then
      desc = "LSP: " .. desc
    end

    vim.keymap.set("n", keys, func, {
      buffer = bufnr,
      desc = desc,
    })
  end

  -- refactoring shortcuts
  lspmap("<leader>ca", vim.lsp.buf.code_action, "[C]ode [a]ction")

  -- going to definitions, references, etc
  lspmap("<leader>gd", vim.lsp.buf.definition, "[G]oto [d]efinition")
  lspmap("<leader>gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
  lspmap("<leader>gr", require("telescope.builtin").lsp_references, "[G]oto [r]eferences")
  lspmap("<leader>gi", vim.lsp.buf.implementation, "[G]oto [i]mplementation")
  lspmap("<leader>gt", vim.lsp.buf.type_definition, "[G]oto [t]ype definition")

  -- symbols
  lspmap("<leader>Sr", vim.lsp.buf.rename, "[R]ename [s]ymbol")
  lspmap("<leader>Sd", require("telescope.builtin").lsp_document_symbols, "[S]ymbols (document)")
  lspmap("<leader>Sw", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[S]ymbols (workspace)")

  -- documentation
  -- TODO: figure out a better keymap for this
  vim.keymap.set({ "i", "n" }, "<C-i>", vim.lsp.buf.signature_help, { buffer = bufnr })

  -- formatting
  lspmap("<leader>f", vim.lsp.buf.format, "[F]ormat buffer")
  vim.api.nvim_create_autocmd("BufWrite", { pattern = "*", callback = vim.lsp.buf.format }) -- format on save

  -- workspace folders
  lspmap("<leader>wa", vim.lsp.buf.add_workspace_folder, "[W]orkspace [A]dd Folder")
  lspmap("<leader>wr", vim.lsp.buf.remove_workspace_folder, "[W]orkspace [R]emove Folder")
  lspmap("<leader>wl", function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, "[W]orkspace [L]ist Folders")
end

-- LSPs to be installed
local servers = {
  -- TODO: figure out why this isn't working
  -- python
  -- pyright = {},
  --
  -- -- rust
  -- rust_analyzer = {},
  -- -- rustfmt = {},
  --
  -- -- web development
  -- html = {},
  -- cssls = {},
  -- emmet_ls = {},

  -- lua
  lua_ls = {
    Lua = {
      workspace = {
        checkThirdParty = false,
      },
      telemetry = {
        enable = false,
      },
    },
  },
}

-- setup neovim lua configuration
require("neodev").setup()

-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

-- Ensure the servers above are installed
local mason_lspconfig = require("mason-lspconfig")

mason_lspconfig.setup({
  ensure_installed = vim.tbl_keys(servers),
})

mason_lspconfig.setup_handlers({
  function(server_name)
    require("lspconfig")[server_name].setup({
      capabilities = capabilities,
      on_attach = on_attach,
      settings = servers[server_name],
    })
  end,
})

-- nvim-cmp setup
local cmp = require("cmp")
local luasnip = require("luasnip")

luasnip.config.setup({
  enable_autosnippets = true,
})

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-n>"] = cmp.mapping.select_next_item(),
    ["<C-p>"] = cmp.mapping.select_prev_item(),
    ["<C-d>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete({}),
    ["<CR>"] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  sources = {
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "omni" },
  },
})

-- load snippets from external file
require("luasnip.loaders.from_lua").load({ paths = "~/.config/nvim/snippets/" })

-- set color scheme
-- TODO: set color scheme to change with system settings?
-- TODO: add keyboard shortcut to toggle color scheme
vim.cmd.colorscheme "everforest"

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
