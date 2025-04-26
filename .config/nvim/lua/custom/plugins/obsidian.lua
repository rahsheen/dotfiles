local obsidian_path = vim.fn.expand '~/mnt/dropbox/Obsidian'
-- Use vim.fn.isdirectory to check if the path exists and is a directory.
-- It returns 1 if true (directory exists), 0 otherwise.
-- We compare with 1 to get a proper Lua boolean (true/false).
local obsidian_exists = vim.fn.isdirectory(obsidian_path) == 1

return {
  'epwalsh/obsidian.nvim',
  version = '*', -- recommended, use latest release instead of latest commit
  lazy = true,
  ft = 'markdown',
  -- Conditionally load the plugin based on whether the directory exists
  cond = obsidian_exists,
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
        path = obsidian_path,
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
