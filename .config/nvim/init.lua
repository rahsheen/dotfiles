-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed
vim.g.have_nerd_font = false

-- Options shared with rahcodes/sets.lua (number, mouse, scrolloff) live there.
vim.opt.relativenumber = true
vim.opt.showmode = false
vim.opt.clipboard = 'unnamedplus'
-- Coder boxes have no clipboard tool, and Neovim never picks OSC 52 by itself while
-- 'clipboard' is set. Copy through OSC 52 (herdr forwards it to Ghostty); paste reads the
-- unnamed register, because a remote terminal clipboard read can hang or prompt.
if vim.fn.has 'mac' == 0 and not vim.env.DISPLAY and not vim.env.WAYLAND_DISPLAY then
  local osc52 = require 'vim.ui.clipboard.osc52'
  local function paste()
    return { vim.fn.split(vim.fn.getreg '', '\n'), vim.fn.getregtype '' }
  end
  vim.g.clipboard = {
    name = 'OSC 52 (copy only)',
    copy = { ['+'] = osc52.copy '+', ['*'] = osc52.copy '*' },
    paste = { ['+'] = paste, ['*'] = paste },
  }
end
vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.inccommand = 'split'
vim.opt.cursorline = true

vim.opt.hlsearch = true
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically

  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            return ']c'
          end
          vim.schedule(function()
            gs.nav_hunk 'next'
          end)
          return '<Ignore>'
        end, { expr = true })

        map('n', '[c', function()
          if vim.wo.diff then
            return '[c'
          end
          vim.schedule(function()
            gs.nav_hunk 'prev'
          end)
          return '<Ignore>'
        end, { expr = true })

        -- Actions
        map('n', '<leader>hs', gs.stage_hunk, { desc = '[H]unk [S]tage' })
        map('n', '<leader>hr', gs.reset_hunk, { desc = '[H]unk [R]eset' })
        map('v', '<leader>hs', function()
          gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = '[H]unk [S]tage' })
        map('v', '<leader>hr', function()
          gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = '[H]unk [R]eset' })
        map('n', '<leader>hS', gs.stage_buffer, { desc = '[S]tage Buffer' })
        -- stage_hunk toggles, so on a staged hunk it unstages.
        map('n', '<leader>hu', gs.stage_hunk, { desc = '[H]unk [U]ndo Stage' })
        map('n', '<leader>hR', gs.reset_buffer, { desc = '[R]eset Buffer' })
        map('n', '<leader>hp', gs.preview_hunk, { desc = '[H]unk [P]review' })
        map('n', '<leader>hb', function()
          gs.blame_line { full = true }
        end, { desc = '[B]lame Line' })
        map('n', '<leader>tb', gs.toggle_current_line_blame, { desc = '[T]oggle [B]lame' })
        map('n', '<leader>hd', gs.diffthis, { desc = '[D]iff This' })
        map('n', '<leader>hD', function()
          gs.diffthis '~'
        end, { desc = '[D]iff [T]his' })
        map('n', '<leader>td', gs.preview_hunk_inline, { desc = '[T]oggle [D]eleted' })

        -- Text object
        map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
      end,
    },
  },

  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {},
    keys = {
      {
        '<leader>?',
        function()
          require('which-key').show { global = false }
        end,
        desc = 'Buffer Local Keymaps (which-key)',
      },
    },
  },

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    version = '*',
    dependencies = {
      'nvim-lua/plenary.nvim',
      -- optional but recommended
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
      { 'nvim-telescope/telescope-ui-select.nvim' },
      -- Major updates must be adjusted manually.
      { 'nvim-telescope/telescope-live-grep-args.nvim', version = '^1.0.0' },
      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      require('telescope').setup {
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
          live_grep_args = {
            auto_quoting = true,
          },
        },
      }

      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')
      pcall(require('telescope').load_extension, 'live_grep_args')

      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>m', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', builtin.git_files, { desc = '[S]earch [G]it Files' })
      vim.keymap.set('n', '<leader>sb', builtin.git_branches, { desc = '[S]earch Git [B]ranches' })
      vim.keymap.set('n', '<leader>sa', function()
        require('telescope').extensions.live_grep_args.live_grep_args()
      end, { desc = 'Live Grep (Args)' })

      vim.keymap.set('n', '<leader>/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      -- Shortcut for searching your neovim configuration files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })

      -- Search only within the current Nx app/lib.
      vim.keymap.set('n', '<leader>sp', function()
        local root = require('rahcodes.nx').root(0)
        builtin.find_files {
          cwd = root or vim.fn.getcwd(),
          prompt_title = 'Find Files in Project Context',
        }
      end, { desc = '[S]earch Current [P]roject' })
    end,
  },

  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },

  { -- LSP Configuration & Plugins
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      'saghen/blink.cmp',
    },
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- To jump back, use <C-o> (harpoon owns <C-t>).
          map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

          map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
          map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
          map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
          map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
          map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
          map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'v' })
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
        end,
      })

      -- blink.cmp registers its own capabilities for '*'. This only pins the encoding so
      -- servers that disagree on utf-8/utf-16 don't warn.
      vim.lsp.config('*', {
        capabilities = {
          offsetEncoding = { 'utf-16' },
          general = { positionEncodings = { 'utf-16' } },
        },
      })

      local servers = {
        lua_ls = {
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
              diagnostics = { disable = { 'missing-fields' } },
            },
          },
        },
        eslint = {},
        jsonls = {},
        tailwindcss = {},
        yamlls = {
          -- Schema validation for YAML. SchemaStore auto-maps the GitHub Workflow schema to
          -- .github/workflows/*.{yml,yaml}, so structural mistakes (e.g. a job whose `steps`
          -- got mis-nested under `strategy`) surface as live diagnostics.
          settings = {
            yaml = {
              schemaStore = { enable = true },
              validate = true,
            },
          },
        },
      }

      for name, config in pairs(servers) do
        vim.lsp.config(name, config)
      end

      require('mason').setup()

      local ensure_installed = vim.tbl_keys(servers)
      vim.list_extend(ensure_installed, {
        'stylua', -- Used to format lua code
        'actionlint', -- Lints GitHub Actions workflows (surfaced via nvim-lint)
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      -- Enables every Mason-installed server; installs come from mason-tool-installer.
      require('mason-lspconfig').setup { ensure_installed = {} }

      -- gdscript is not installed through Mason; it only attaches in gdscript buffers.
      vim.lsp.enable 'gdscript'
      vim.lsp.config('ruby_lsp', {
        cmd = { vim.fn.expand '~/.local/bin/launch-ruby-lsp.sh' },
      })
      vim.lsp.enable 'ruby_lsp'
    end,
  },

  { -- Autoformat
    'stevearc/conform.nvim',
    lazy = false,
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = { 'n', 'v' },
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = true,
      format_on_save = function(bufnr)
        local ft = vim.bo[bufnr].filetype
        if ft == 'json' or ft == 'ruby' then
          return
        end
        return { timeout_ms = 2000, lsp_format = 'fallback' }
      end,
      -- rubocop --no-server can take several seconds, so Ruby formats after the write
      -- instead of blocking it.
      format_after_save = function(bufnr)
        if vim.bo[bufnr].filetype == 'ruby' then
          return { timeout_ms = 20000 }
        end
      end,
      log_level = vim.log.levels.WARN,
      formatters = {
        rubocop_no_server = {
          command = 'rubocop',
          args = {
            '--no-server', -- CRITICAL: Prevents server usage
            '-a',
            '--fix-layout',
            '--stderr',
            '--stdin',
            '$FILENAME',
          },
          exit_codes = { 0, 1 },
        },
      },
      formatters_by_ft = {
        lua = { 'stylua' },
        ruby = { 'rubocop_no_server', lsp_format = 'never' },
        typescript = { 'prettierd', 'prettier', stop_after_first = true },
        typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },
        javascript = { 'prettierd', 'prettier', stop_after_first = true },
        javascriptreact = { 'prettierd', 'prettier', stop_after_first = true },
      },
    },
  },
  {
    'saghen/blink.cmp',
    -- The snippets source reads friendly-snippets directly.
    dependencies = { 'rafamadriz/friendly-snippets' },
    -- A release tag downloads the pre-built fuzzy matcher.
    version = '1.*',

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = { preset = 'default' },
      appearance = { nerd_font_variant = 'mono' },
      completion = { documentation = { auto_show = false } },
      sources = {
        default = { 'lazydev', 'lsp', 'path', 'snippets', 'buffer' },
        providers = {
          lazydev = { name = 'LazyDev', module = 'lazydev.integrations.blink', score_offset = 100 },
        },
      },
      fuzzy = { implementation = 'prefer_rust_with_warning' },
    },
    opts_extend = { 'sources.default' },
  },
  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [']quote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      local MiniStatusline = require 'mini.statusline'
      MiniStatusline.setup {
        content = {
          active = function()
            -- 1. Force these to ALWAYS show by setting trunc_width to 0
            local mode, mode_hl = MiniStatusline.section_mode { trunc_width = 0 }
            local git = MiniStatusline.section_git { trunc_width = 0 }
            local diagnostics = MiniStatusline.section_diagnostics { trunc_width = 0 }

            -- rubocop_todo.nvim. Returns '' unless .rubocop_todo.yml excludes this file
            -- from a cop, and combine_groups drops empty strings. pcall'd so a plugin
            -- load failure can't break every statusline redraw.
            local ok_rubocop, rubocop_todo = pcall(require, 'rubocop_todo')
            local rubocop = ok_rubocop and rubocop_todo.statusline() or ''

            -- 2. Standard info for the right side
            local fileinfo = MiniStatusline.section_fileinfo { trunc_width = 120 }
            local location = '%2l:%-2v'

            -- 3. Custom Smart Path Logic
            -- Result example: "󱃾 my-lib › .../components/Button.tsx"
            local nx_project = require('rahcodes.nx').name(0)

            -- Get last 2 parts of the path (e.g., 'components/Button.tsx')
            local path = vim.fn.expand '%:p'
            local parts = vim.split(path, '/')
            local short_path = ''
            if #parts >= 2 then
              short_path = parts[#parts - 1] .. '/' .. parts[#parts]
            else
              short_path = parts[#parts] or ''
            end

            local nx_display = string.format('%s › %s%s', nx_project, (#parts > 2 and '…/' or ''), short_path)

            -- 4. Combine everything
            return MiniStatusline.combine_groups {
              { hl = mode_hl, strings = { mode } },
              { hl = 'MiniStatuslineDevinfo', strings = { git, diagnostics, rubocop } },
              -- This section will now yield space to the left side
              { hl = 'MiniStatuslineFilename', strings = { nx_display } },
              '%=',
              { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
              { hl = mode_hl, strings = { location } },
            }
          end,
        },
      }
    end,
  },
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      local ts = require 'nvim-treesitter'
      local parsers = ts.install {
        'bash', 'c', 'diff', 'dockerfile', 'embedded_template', 'git_config', 'git_rebase', 'gitcommit', 'gitignore',
        'graphql', 'html', 'javascript', 'json', 'lua', 'markdown', 'markdown_inline', 'python', 'ruby', 'sql', 'terraform',
        'toml', 'tsx', 'typescript', 'vim', 'vimdoc', 'yaml',
      }
      -- install.sh bootstraps headlessly; without the wait, +qa kills the parser builds.
      if vim.env.NVIM_BOOTSTRAP then
        parsers:wait(600000)
      end

      local function start(buf, lang)
        if vim.api.nvim_buf_is_valid(buf) and pcall(vim.treesitter.start, buf, lang) then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end

      -- main has no auto_install: install a missing parser on first use, then start it.
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter-start', { clear = true }),
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(ev.match)
          if not lang then
            return
          end
          if vim.treesitter.language.add(lang) then
            start(ev.buf, lang)
          elseif vim.tbl_contains(ts.get_available(), lang) then
            ts.install(lang):await(vim.schedule_wrap(function()
              start(ev.buf, lang)
            end))
          end
        end,
      })
    end,
  },
  { 'j-hui/fidget.nvim', opts = {} },

  { import = 'custom.plugins' },
}, {
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

require 'rahcodes.remap'
require 'rahcodes.sets'
-- vim: ts=2 sts=2 sw=2 et
