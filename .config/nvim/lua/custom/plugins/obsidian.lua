local obsidian_path = vim.fn.expand '~/mnt/dropbox/Obsidian'

return {
  'obsidian-nvim/obsidian.nvim',
  version = '*',
  ft = 'markdown',
  -- Only machines with the Dropbox vault mounted load the plugin.
  cond = vim.fn.isdirectory(obsidian_path) == 1,
  dependencies = { 'nvim-telescope/telescope.nvim' },
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false,
    picker = { name = 'telescope.nvim' },
    workspaces = {
      {
        name = 'primary',
        path = obsidian_path,
      },
    },
    templates = {
      folder = 'Templates',
      date_format = '%Y-%m-%d-%a',
      time_format = '%H:%M',
    },
    ui = { enable = false },
  },
  keys = {
    { '<leader>ox', ':Obsidian extract_note<CR>', mode = 'v', desc = '[O]bsidian E[x]ract Note' },
    { '<leader>ol', ':Obsidian link<CR>', mode = 'v', desc = '[O]bsidian [L]ink' },
    { '<leader>on', '<cmd>Obsidian new<CR>', desc = '[O]bsidian [N]ew Note' },
    { '<leader>od', '<cmd>Obsidian today<CR>', desc = '[O]bsidian [T]oday' },
    { '<leader>oy', '<cmd>Obsidian yesterday<CR>', desc = '[O]bsidian [Y]esterday' },
    { '<leader>ost', '<cmd>Obsidian template<CR>', desc = '[O]bsidian [T]emplate' },
    { '<leader>so', '<cmd>Obsidian search<CR>', desc = '[O]bsidian [S]earch' },
  },
}
