return {
  {
    'ThePrimeagen/refactoring.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    config = function()
      require('refactoring').setup()
    end,
  },
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = {},
  },
  {
    'folke/trouble.nvim',
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
      require('trouble').setup {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
        icons = false,
      }

      -- Trouble bindings
      vim.keymap.set('n', '<leader>xx', function()
        require('trouble').open()
      end)
      vim.keymap.set('n', '<leader>xw', function()
        require('trouble').open 'workspace_diagnostics'
      end)
      vim.keymap.set('n', '<leader>xd', function()
        require('trouble').open 'document_diagnostics'
      end)
      vim.keymap.set('n', '<leader>xq', function()
        require('trouble').open 'quickfix'
      end)
      vim.keymap.set('n', '<leader>xl', function()
        require('trouble').open 'loclist'
      end)
      vim.keymap.set('n', 'gR', function()
        require('trouble').open 'lsp_references'
      end)
    end,
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
          { '<leader>sga', ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>", desc = 'Live Grep (Args)' },
        },
        config = function()
          require('telescope').load_extension 'live_grep_args'
        end,
      },
    },
  },
  {
    'tpope/vim-fugitive',
    dependencies = { { 'tpope/vim-rhubarb' } },
    config = function()
      vim.keymap.set('n', '<leader>gs', ':G<CR>')
      vim.keymap.set('n', '<leader>gh', ':diffget //3<CR>')
      vim.keymap.set('n', '<leader>gu', ':diffget //2<CR>')
      vim.keymap.set('n', '<leader>gc', ':GCheckout<CR>')
      vim.keymap.set('n', '<leader>ga', ':G add %:p<CR><CR>')
      vim.keymap.set('n', '<leader>gc', ':G commit -v -q<CR>')
      vim.keymap.set('n', '<leader>gt', ':G commit -v -q %:p<CR>')
      vim.keymap.set('n', '<leader>gff', ':G ff<CR>')
      vim.keymap.set('n', '<leader>gfo', ':G fetch origin<CR>')
      vim.keymap.set('n', '<leader>gd', ':Gdiff<CR>')
      vim.keymap.set('n', '<leader>ge', ':Gedit<CR>')
      vim.keymap.set('n', '<leader>gr', ':Gread<CR>')
      vim.keymap.set('n', '<leader>grb', ':G rebase -i<CR>')
      vim.keymap.set('n', '<leader>gw', ':Gwrite<CR><CR>')
      vim.keymap.set('n', '<leader>gl', ':silent! Glog<CR>:bot copen<CR>')
      vim.keymap.set('n', '<leader>gp', ':Ggrep<Space>')
      vim.keymap.set('n', '<leader>gm', ':Gmove<Space>')
      vim.keymap.set('n', '<leader>gbl', ':G blame<CR>')
      vim.keymap.set('n', '<leader>go', ':G checkout<Space>')
      vim.keymap.set('n', '<leader>gps', ':Dispatch! git push<CR>')
      vim.keymap.set('n', '<leader>gpl', ':Dispatch! git pull<CR>')
    end,
  },
  { 'github/copilot.vim' },
  {
    'pmizio/typescript-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
    opts = {},
  },
}
