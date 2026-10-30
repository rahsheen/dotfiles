return {
  { -- Lint GitHub Actions workflows with actionlint (clearer messages than the yamlls schema).
    'mfussenegger/nvim-lint',
    event = 'VeryLazy',
    config = function()
      local lint = require 'lint'
      lint.linters_by_ft = { yaml = { 'actionlint' } }

      -- actionlint is only meaningful for workflow files, so gate on the path inside the
      -- callback (autocmd path patterns are unreliable). Includes BufReadPost so it runs on
      -- open, not just save.
      vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost', 'InsertLeave' }, {
        group = vim.api.nvim_create_augroup('nvim-lint-actions', { clear = true }),
        callback = function(args)
          local name = vim.api.nvim_buf_get_name(args.buf)
          if name:match '%.github/workflows/.*%.ya?ml$' then
            lint.try_lint()
          end
        end,
      })
    end,
  },
  {
    'ThePrimeagen/refactoring.nvim',
    dependencies = {
      -- Required since upstream moved to lua/refactoring.lua, which does
      -- `require "async"`. Without it: "module 'async' not found" at startup.
      'lewis6991/async.nvim',
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    opts = {},
    keys = {
      {
        '<leader>rr',
        function()
          require('refactoring').select_refactor()
        end,
        mode = { 'n', 'x' },
        desc = '[R]efactor',
      },
    },
  },
  {
    'tpope/vim-fugitive',
    dependencies = { { 'tpope/vim-rhubarb' } },
    keys = {
      { '<leader>gs', vim.cmd.Git },
      { '<leader>gh', ':diffget //3<CR>' },
      { '<leader>gu', ':diffget //2<CR>' },
      { '<leader>gc', ':G commit -v -q<CR>' },
      { '<leader>gff', ':G ff<CR>' },
      { '<leader>gfo', ':G fetch origin<CR>' },
      { '<leader>gb', ':G blame<CR>' },
      { '<leader>gr', ':GBrowse!<CR>', mode = { 'n', 'v' }, desc = 'Browse on github' },
    },
    config = function()
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('ThePrimeagen_Fugitive', { clear = true }),
        pattern = 'fugitive',
        callback = function(ev)
          local opts = { buffer = ev.buf, remap = false }
          vim.keymap.set('n', '<leader>p', function()
            vim.cmd.Git 'push'
          end, opts)

          -- rebase always
          vim.keymap.set('n', '<leader>P', function()
            vim.cmd.Git 'pull --rebase'
          end, opts)

          vim.keymap.set('n', '<leader>f', function()
            vim.cmd.Git 'fetch origin'
          end, opts)

          -- NOTE: It allows me to easily set the branch i am pushing and any tracking
          -- needed if i did not set the branch up correctly
          vim.keymap.set('n', '<leader>t', ':Git push -u origin ', opts)
        end,
      })
    end,
  },
  {
    'pmizio/typescript-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
    opts = {
      settings = {
        expose_as_code_action = 'all',
        tsserver_file_preferences = {
          includeInlayParameterNameHints = 'all',
          includeCompletionsForModuleExports = true,
          quotePreference = 'single',
          importModuleSpecifierPreference = 'relative',
        },
      },
    },
  },
  {
    'ThePrimeagen/harpoon',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('harpoon').setup {}
      local silent = { silent = true }

      vim.keymap.set('n', '<leader>a', function()
        require('harpoon.mark').add_file()
      end, { desc = 'Harpoon [A[dd' })
      vim.keymap.set('n', '<C-e>', function()
        require('harpoon.ui').toggle_quick_menu()
      end, silent)
      vim.keymap.set('n', '<leader>tc', function()
        require('harpoon.cmd-ui').toggle_quick_menu()
      end, silent)

      vim.keymap.set('n', '<C-h>', function()
        require('harpoon.ui').nav_file(1)
      end, silent)
      vim.keymap.set('n', '<C-t>', function()
        require('harpoon.ui').nav_file(2)
      end, silent)
      vim.keymap.set('n', '<C-n>', function()
        require('harpoon.ui').nav_file(3)
      end, silent)
      vim.keymap.set('n', '<C-s>', function()
        require('harpoon.ui').nav_file(4)
      end, silent)
    end,
  },
  {
    'tpope/vim-rails',
    dependencies = { 'tpope/vim-dispatch', 'tpope/vim-dadbod', 'tpope/vim-abolish', 'tpope/vim-bundler' },
  },
}
