return {
  {
    'ThePrimeagen/git-worktree.nvim',
    -- dependencies = 'telescope',
    config = function()
      local Worktree = require 'git-worktree'

      -- op = Operations.Switch, Operations.Create, Operations.Delete
      -- metadata = table of useful values (structure dependent on op)
      --      Switch
      --          path = path you switched to
      --          prev_path = previous worktree path
      --      Create
      --          path = path where worktree created
      --          branch = branch name
      --          upstream = upstream remote name
      --      Delete
      --          path = path where worktree deleted

      Worktree.on_tree_change(function(op, metadata)
        if op == Worktree.Operations.Switch then
          -- Delete all buffers except the current one
          local bufs = vim.api.nvim_list_bufs()
          local current_buf = vim.api.nvim_get_current_buf()
          for _, i in ipairs(bufs) do
            if i ~= current_buf then
              vim.api.nvim_buf_delete(i, {})
            end
          end

          print('Switched from ' .. metadata.prev_path .. ' to ' .. metadata.path)
        end
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
  },
}
