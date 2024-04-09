return {
  'epwalsh/obsidian.nvim',
  version = '*', -- recommended, use latest release instead of latest commit
  lazy = true,
  ft = 'markdown',
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  -- event = {
  --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/**.md"
  --   "BufReadPre path/to/my-vault/**.md",
  --   "BufNewFile path/to/my-vault/**.md",
  -- },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'hrsh7th/nvim-cmp',
    'nvim-telescope/telescope.nvim',
  },
  opts = {
    picker = { name = 'telescope.nvim' },
    workspaces = {
      {
        name = 'primary',
        path = '~/Dropbox/Obsidian',
      },
    },
    templates = {
      subdir = 'Templates',
      date_format = '%Y-%m-%d-%a',
      time_format = '%H:%M',
    },
  },
  keys = {
    { '<leader>ox', ':ObsidianExtractNote<CR>', mode = 'v', desc = '[O]bsidian E[x]ract Note' },
    { '<leader>ol', ':ObsidianLink<CR>', mode = 'v', desc = '[O]bsidian [L]ink' },
    { '<leader>on', ':ObsidianNew<CR>', desc = '[O]bsidian [N]ew Note' },
    { '<leader>od', ':ObsidianToday<CR>', desc = '[O]bsidian [T]oday' },
    { '<leader>oy', ':ObsidianYesterday<CR>', desc = '[O]bsidian [Y]esterday' },
    { '<leader>ost', ':ObsidianTemplate<CR>', desc = '[O]bsidian [T]emplate' },
    { '<leader>so', ':ObsidianSearch<CR>', desc = '[O]bsidian [S]earch' },
  },
}
