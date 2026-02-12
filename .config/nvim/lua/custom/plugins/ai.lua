return {
  {
    'ravitemer/mcphub.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    build = 'npm install -g mcp-hub@latest && asdf reshim nodejs', -- Installs `mcp-hub` node binary globally
    config = function()
      require('mcphub').setup {
        extensions = {
          avante = {
            make_slash_commands = true, -- make /slash commands from MCP server prompts
          },
        },
      }
    end,
  },
  {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    event = 'InsertEnter',
    config = function()
      require('copilot').setup {
        suggestion = {
          enabled = true,
          auto_trigger = false, -- This keeps it silent!
          keymap = {
            -- Set these to false to prevent the "Double Mapping" you saw
            accept = false,
            next = false,
            prev = false,
            dismiss = false,
          },
        },
        panel = { enabled = false },
        filetypes = {
          ['*'] = true, -- Enable for all filetypes
        },
      }

      -- Manual trigger for Copilot ghost text
      vim.keymap.set('i', '<C-a>', function()
        require('copilot.suggestion').next()
      end, { desc = 'Trigger Copilot Suggestion' })

      -- Force M-l to accept even if the internal keymap is failing
      vim.keymap.set('i', '<C-l>', function()
        if require('copilot.suggestion').is_visible() then
          require('copilot.suggestion').accept()
        else
          -- Optional: If no suggestion, do what M-l normally does (or nothing)
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<M-l>', true, true, true), 'n', false)
        end
      end, { desc = 'Force Accept Copilot' })
    end,
  },
  {
    'yetone/avante.nvim',
    build = 'make',
    event = 'VeryLazy',
    version = false,
    opts = {
      provider = 'copilot',
      -- "agentic" mode is required for the LLM to actually use the tools MCPHub provides
      mode = 'agentic',
      auto_suggestions_provider = 'copilot',
      -- Bridge Avante to MCPHub
      custom_tools = function()
        return {
          require('mcphub.extensions.avante').mcp_tool(),
        }
      end,
      -- Optional: help the LLM understand what tools are available
      -- system_prompt as function ensures LLM always has latest MCP server state
      -- This is evaluated for every message, even in existing chats
      system_prompt = function()
        local hub = require('mcphub').get_hub_instance()
        if hub then
          return hub:get_active_servers_prompt()
        end
      end,
      hints = { enabled = false },
      disabled_tools = {
        'list_files', -- Built-in file operations
        'search_files',
        'read_file',
        'create_file',
        'rename_file',
        'delete_file',
        'create_dir',
        'rename_dir',
        'delete_dir',
        'bash', -- Built-in terminal access
      },
    },
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'echasnovski/mini.pick',
      'nvim-telescope/telescope.nvim',
      'hrsh7th/nvim-cmp',
      'ibhagwan/fzf-lua',
      'stevearc/dressing.nvim',
      'folke/snacks.nvim',
      'nvim-tree/nvim-web-devicons',
      'zbirenbaum/copilot.lua',
      {
        'HakonHarnes/img-clip.nvim',
        event = 'VeryLazy',
        opts = {
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = { insert_mode = true },
            use_absolute_path = true,
          },
        },
      },
      {
        'MeanderingProgrammer/render-markdown.nvim',
        opts = { file_types = { 'markdown', 'Avante' } },
        ft = { 'markdown', 'Avante' },
      },
    },
  },
}
