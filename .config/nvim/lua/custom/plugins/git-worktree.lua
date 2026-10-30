return {
  'polarmutex/git-worktree.nvim',
  version = '^2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local hooks = require 'git-worktree.hooks'

    hooks.register(hooks.type.SWITCH, function(path, prev_path)
      -- Close the other listed buffers; modified ones stay open so no edits are lost.
      local current_buf = vim.api.nvim_get_current_buf()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if buf ~= current_buf and vim.bo[buf].buflisted and not vim.bo[buf].modified then
          vim.api.nvim_buf_delete(buf, {})
        end
      end

      print('Switched from ' .. (prev_path or '?') .. ' to ' .. path)
    end)
  end,
  keys = {
    {
      '<leader>gw',
      function()
        require('telescope').extensions.git_worktree.git_worktrees()
      end,
      desc = '[G]it [W]orktrees',
    },
    {
      '<leader>cw',
      function()
        require('telescope').extensions.git_worktree.create_git_worktree()
      end,
      desc = '[C]reate Git [W]orktree',
    },
  },
}
