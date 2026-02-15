return {
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = {
      style = 'moon',
      transparent = false,
      styles = {
        comments = { italic = true },
        keywords = { italic = true, bold = true },
        functions = { bold = true },
      },
      on_highlights = function(hl, c)
        -- ---------------------------------------------------------
        -- 1. LAW OF DEMETER (The "Red Dot" Signal)
        -- Targets dots, colons, and accessors in Ruby & TS
        -- ---------------------------------------------------------
        hl['@punctuation.coupling'] = { fg = c.red, bold = true }
        --
        -- Make the dot a very subtle, dark color so it doesn't scream at you.
        -- hl['@punctuation.accessor.ruby'] = { fg = c.dark3 }
        -- hl['@punctuation.accessor.typescript'] = { fg = c.dark3 }

        -- 2. THE YELLOW WARNING (Optional Chaining ?.)
        -- In TS, this says: "I'm reaching deep, but I'm being safe."
        -- Yellow is a great "Caution" color here.
        hl['@punctuation.accessor.optional'] = { fg = c.red, bold = true }

        -- ---------------------------------------------------------
        -- 2. EXTERNAL COUPLING (The "Orange" Alert)
        -- Highlighting Gem namespaces and TS Classes/Types
        -- ---------------------------------------------------------
        local external_deps = {
          '@constant.ruby', -- Spree, Devise, etc.
          '@type.ruby', -- User, Order
          '@type.typescript', -- Interfaces/Types
          '@constructor.typescript', -- new User()
          '@constant.typescript', -- Imported constants
        }
        for _, group in ipairs(external_deps) do
          hl[group] = { fg = c.orange, bold = true }
        end

        -- ---------------------------------------------------------
        -- 3. THE "SELF" BUBBLE (The "Teal" Safe Zone)
        -- Distinguishes internal state from external reach
        -- ---------------------------------------------------------
        hl['@variable.builtin.ruby'] = { fg = c.teal, italic = true } -- self
        hl['@variable.builtin.typescript'] = { fg = c.teal, italic = true } -- this

        -- ---------------------------------------------------------
        -- 4. MESSAGES/ACTIONS (The "Blue" Flow)
        -- Standardizes method calls across both languages
        -- ---------------------------------------------------------
        hl['@function.call.ruby'] = { fg = c.blue }
        hl['@function.call.typescript'] = { fg = c.blue }
        hl['@method.typescript'] = { fg = c.blue }
      end,
    },
    config = function(_, opts)
      require('tokyonight').setup(opts)
      vim.cmd.colorscheme 'tokyonight-moon'
    end,
  },
}
