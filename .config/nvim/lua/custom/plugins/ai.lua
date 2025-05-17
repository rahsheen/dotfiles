return {
  {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    event = 'InsertEnter',
    config = function()
      require('copilot').setup {}
    end,
  },
  {
    'yetone/avante.nvim',
    event = 'VeryLazy',
    lazy = true,
    -- version = false, -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
    commit = 'f9aa754',
    opts = {
      provider = 'copilot',
      auto_suggestions_provider = nil,
      -- vendors = {
      --   ---@type AvanteProvider
      --   ollama = {
      --     api_key_name = '',
      --     ask = '',
      --     endpoint = 'http://localhost:11434/api',
      --     model = 'deepseek-coder:33b',
      --     parse_curl_args = function(opts, code_opts)
      --       return {
      --         url = opts.endpoint .. '/chat',
      --         headers = {
      --           ['Accept'] = 'application/json',
      --           ['Content-Type'] = 'application/json',
      --         },
      --         body = {
      --           model = opts.model,
      --           options = {
      --             num_ctx = 16384,
      --           },
      --           messages = require('avante.providers').copilot.parse_messages(code_opts), -- you can make your own message, but this is very advanced
      --           stream = true,
      --         },
      --       }
      --     end,
      --     parse_stream_data = function(data, handler_opts)
      --       -- Parse the JSON data
      --       local json_data = vim.fn.json_decode(data)
      --       -- Check for stream completion marker first
      --       if json_data and json_data.done then
      --         handler_opts.on_complete(nil) -- Properly terminate the stream
      --         return
      --       end
      --       -- Process normal message content
      --       if json_data and json_data.message and json_data.message.content then
      --         -- Extract the content from the message
      --         local content = json_data.message.content
      --         -- Call the handler with the content
      --         handler_opts.on_chunk(content)
      --       end
      --     end,
      --     -- parse_response_data = function(data_stream, event_state, opts)
      --     --   require('avante.providers').copilot.parse_response(data_stream, event_state, opts)
      --     -- end,
      --   },
      -- },
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = 'make',
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      'stevearc/dressing.nvim',
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      --- The below dependencies are optional,
      'echasnovski/mini.pick', -- for file_selector provider mini.pick
      'nvim-telescope/telescope.nvim', -- for file_selector provider telescope
      'hrsh7th/nvim-cmp', -- autocompletion for avante commands and mentions
      'ibhagwan/fzf-lua', -- for file_selector provider fzf
      'nvim-tree/nvim-web-devicons', -- or echasnovski/mini.icons
      'zbirenbaum/copilot.lua',
      {
        -- support for image pasting
        'HakonHarnes/img-clip.nvim',
        event = 'VeryLazy',
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { 'markdown', 'Avante' },
        },
        ft = { 'markdown', 'Avante' },
      },
    },
  },
  -- {
  --   'supermaven-inc/supermaven-nvim',
  --   enabled = function()
  --     return os.getenv 'USER' ~= 'coder' and os.getenv 'USER' ~= 'rahsheenporter'
  --   end,
  --   config = function()
  --     require('supermaven-nvim').setup {
  --       disable_keymaps = true,
  --       disable_inline_completion = true,
  --     }
  --   end,
  -- },
}
