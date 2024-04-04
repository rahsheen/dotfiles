return {
  {
    'ThePrimeagen/git-worktree.nvim',
    dependencies = 'telescope',
    config = function()
      local Worktree = require 'git-worktree'
      Worktree.setup()

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
          print('Switched from ' .. metadata.prev_path .. ' to ' .. metadata.path)
        end
      end)
    end,
    keys = {
      { '<leader>bw', require('telescope').extensions.git_worktree.git_worktrees, desc = '[B]rowse Git Worktrees' },
      { '<leader>cw', require('telescope').extensions.git_worktree.create_git_worktree, desc = '[C]reate Git [W]orktree' },
    },
  },
}
