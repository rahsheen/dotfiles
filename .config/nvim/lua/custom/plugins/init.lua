return {
  {
    'ThePrimeagen/refactoring.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    config = function()
      require('refactoring').setup {}
    end,
  },
  -- {
  --   'folke/tokyonight.nvim',
  --   lazy = false,
  --   priority = 1000,
  --   opts = {},
  -- },
  -- {
  --   'folke/trouble.nvim',
  --   dependencies = 'nvim-tree/nvim-web-devicons',
  --   config = function()
  --     require('trouble').setup {
  --       -- your configuration comes here
  --       -- or leave it empty to use the default settings
  --       -- refer to the configuration section below
  --       icons = false,
  --     }
  --
  --     -- Trouble bindings
  --     vim.keymap.set('n', '<leader>xx', function()
  --       require('trouble').open()
  --     end)
  --     vim.keymap.set('n', '<leader>xw', function()
  --       require('trouble').open 'workspace_diagnostics'
  --     end)
  --     vim.keymap.set('n', '<leader>xd', function()
  --       require('trouble').open 'document_diagnostics'
  --     end)
  --     vim.keymap.set('n', '<leader>xq', function()
  --       require('trouble').open 'quickfix'
  --     end)
  --     vim.keymap.set('n', '<leader>xl', function()
  --       require('trouble').open 'loclist'
  --     end)
  --     vim.keymap.set('n', 'gR', function()
  --       require('trouble').open 'lsp_references'
  --     end)
  --   end,
  -- },
  {
    'L3MON4D3/LuaSnip',
    dependencies = { 'rafamadriz/friendly-snippets' },
  },
  {
    'rafamadriz/friendly-snippets',
    config = function()
      require('luasnip.loaders.from_vscode').lazy_load()
    end,
  },
  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    dependencies = {
      {
        'nvim-telescope/telescope-live-grep-args.nvim',
        -- This will not install any breaking changes.
        -- For major updates, this must be adjusted manually.
        version = '^1.0.0',
        keys = {
          { '<leader>sa', ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>", desc = 'Live Grep (Args)' },
        },
        config = function()
          local lga_actions = require 'telescope-live-grep-args.actions'

          require('telescope').setup {
            extensions = {
              live_grep_args = {
                auto_quoting = true, -- enable/disable auto-quoting
                -- define mappings, e.g.
                -- mappings = { -- extend mappings
                --   i = {
                --     ['<C-k>'] = lga_actions.quote_prompt(),
                --     ['<C-i>'] = lga_actions.quote_prompt { postfix = ' --iglob ' },
                --   },
                -- },
                -- ... also accepts theme settings, for example:
                -- theme = "dropdown", -- use dropdown theme
                -- theme = { }, -- use own theme spec
                -- layout_config = { mirror=true }, -- mirror preview pane
              },
            },
          }

          pcall(require('telescope').load_extension, 'live_grep_args')
        end,
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
      -- { '<leader>gc', ':GCheckout<CR>' },
      -- { '<leader>ga', ':G add %:p<CR><CR>' },
      { '<leader>gc', ':G commit -v -q<CR>' },
      -- { '<leader>gt', ':G commit -v -q %:p<CR>' },
      { '<leader>gff', ':G ff<CR>' },
      { '<leader>gfo', ':G fetch origin<CR>' },
      -- { '<leader>gd', ':Gdiff<CR>' },
      -- { '<leader>ge', ':Gedit<CR>' },
      -- { '<leader>gr', ':Gread<CR>' },
      -- { '<leader>grb', ':G rebase -i<CR>' },
      -- { '<leader>gw', ':Gwrite<CR><CR>' },
      -- { '<leader>gl', ':silent! Glog<CR>:bot copen<CR>' },
      -- { '<leader>gp', ':ggrep<space>' },
      -- { '<leader>gm', ':Gmove<Space>' },
      { '<leader>gb', ':G blame<CR>' },
      { '<leader>gr', ':GBrowse!<CR>', mode = { 'n', 'v' }, desc = 'Browse on github' },
      -- { '<leader>go', ':G checkout<Space>' },
      -- { '<leader>gps', ':Dispatch! git push<CR>' },
      -- { '<leader>gpl', ':Dispatch! git pull<CR>' },
    },
    config = function()
      local ThePrimeagen_Fugitive = vim.api.nvim_create_augroup('ThePrimeagen_Fugitive', {})

      local autocmd = vim.api.nvim_create_autocmd
      autocmd('BufWinEnter', {
        group = ThePrimeagen_Fugitive,
        pattern = '*',
        callback = function()
          if vim.bo.ft ~= 'fugitive' then
            return
          end

          local bufnr = vim.api.nvim_get_current_buf()
          local opts = { buffer = bufnr, remap = false }
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
    opts = {},
    config = function()
      require('typescript-tools').setup {
        settings = { expose_as_code_action = 'all' },
      }
    end,
  },
  -- Lua
  -- {
  --   'folke/zen-mode.nvim',
  --   opts = {
  --     -- your configuration comes here
  --     -- or leave it empty to use the default settings
  --     -- refer to the configuration section below
  --   },
  -- },
  -- {
  --   'mbbill/undotree',
  --   config = function()
  --     vim.keymap.set('n', '<leader>5', vim.cmd.UndotreeToggle)
  --   end,
  -- },
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
  -- {
  --   'nvim-neotest/neotest',
  --   lazy = true,
  --   dependencies = {
  --     'nvim-neotest/nvim-nio',
  --     'nvim-lua/plenary.nvim',
  --     'antoinemadec/FixCursorHold.nvim',
  --     'nvim-treesitter/nvim-treesitter',
  --     'olimorris/neotest-rspec',
  --   },
  --   config = function()
  --     require('neotest').setup {
  --       adapters = {
  --         require 'neotest-rspec',
  --       },
  --     }
  --   end,
  -- },
  {
    'tpope/vim-rails',
    dependencies = { 'tpope/vim-dispatch', 'tpope/vim-dadbod', 'tpope/vim-abolish', 'tpope/vim-bundler' },
  },
}
