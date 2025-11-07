return {
  url = 'https://gitlab.com/schrieveslaach/sonarlint.nvim',
  ft = {
    'javascript',
    'typescript',
    'javascriptreact',
    'typescriptreact',
    'ruby',
  },
  -- Only enable when working at Roadrunner Waste Management
  enabled = function()
    local user = os.getenv 'USER'
    local hostname_cmd_output = io.popen('hostname'):read '*l' -- Capture the raw output
    local hostname = hostname_cmd_output:gsub('%s+', '') -- Optional: Try to remove all whitespace
    -- Or, if you suspect only leading/trailing spaces:
    -- local hostname = hostname_cmd_output:match("^%s*(.-)%s*$")

    local should_enable = user == 'coder' or hostname == 'RR-KY3CNX34RY'

    -- print '--- Debugging Plugin Load ---'
    -- print("User: '" .. user .. "'")
    -- print("Hostname (from command, raw): '" .. hostname_cmd_output .. "'")
    -- print("Hostname (after trim/gsub, for comparison): '" .. hostname .. "'")
    -- print("Is user 'coder'?: " .. tostring(user == 'coder'))
    -- print("Is hostname 'RR-KY3CNX34RY'?: " .. tostring(hostname == 'RR-KY3CNX34RY'))
    -- print("Final 'enabled' decision (should_enable): " .. tostring(should_enable))
    -- print '--- End Debugging ---'

    return should_enable
  end,
  config = function()
    require('sonarlint').setup {
      server = {
        cmd = {
          'sonarlint-language-server',
          '-stdio',
          '-analyzers',
          vim.fn.expand '$MASON/share/sonarlint-analyzers/sonarcfamily.jar',
          vim.fn.expand '$MASON/share/sonarlint-analyzers/sonarjs.jar',
        },
      },
      filetypes = {
        'javascript',
        'typescript',
        'javascriptreact',
        'typescriptreact',
        'ruby',
      },
      settings = {
        sonarlint = {
          endrules = {
            -- ----------------------------------------------------------------------
            -- 🧱 EXISTING TYPESCRIPT & RUBY RULES (FROM YOUR ORIGINAL CONFIG)
            -- ----------------------------------------------------------------------
            ['typescript:S6019'] = { level = 'on' },
            ['typescript:S6035'] = { level = 'on' },
            ['typescript:S2933'] = { level = 'on' },
            ['typescript:S1607'] = { level = 'on' },
            ['typescript:S6079'] = { level = 'on' },
            ['typescript:S5264'] = { level = 'on' },
            ['typescript:S2685'] = { level = 'on' },
            ['typescript:S2871'] = { level = 'on' },
            ['typescript:S6959'] = { level = 'on' },
            ['typescript:S6590'] = { level = 'on' },
            ['typescript:S4123'] = { level = 'on' },
            ['typescript:S6836'] = { level = 'on' },
            ['typescript:S2737'] = { level = 'on' },
            ['typescript:S6761'] = { level = 'on' },
            ['typescript:S4524'] = { level = 'on' },
            ['typescript:S3001'] = { level = 'on' },
            ['typescript:S2870'] = { level = 'on' },
            ['typescript:S4138'] = { level = 'on' },
            ['typescript:S1994'] = { level = 'on' },
            ['typescript:S1301'] = { level = 'on' },
            ['typescript:S1862'] = { level = 'on' },
            ['typescript:S4619'] = { level = 'on' },
            ['typescript:S2692'] = { level = 'on' },
            ['typescript:S4156'] = { level = 'on' },
            ['typescript:S2688'] = { level = 'on' },
            ['typescript:S2999'] = { level = 'on' },
            ['typescript:S6679'] = { level = 'on' },
            ['typescript:S6594'] = { level = 'on' },
            ['typescript:S6756'] = { level = 'on' },
            ['typescript:S6763'] = { level = 'on' },
            ['typescript:S3854'] = { level = 'on' },
            ['typescript:S1219'] = { level = 'on' },
            ['typescript:S1479'] = { level = 'on' },
            ['typescript:S6841'] = { level = 'on' },
            ['typescript:S6757'] = { level = 'on' },
            ['typescript:S4623'] = { level = 'on' },
            ['typescript:S3735'] = { level = 'on' },
            ['typescript:S6654'] = { level = 'on' },
            ['typescript:S2251'] = { level = 'on' },
            ['typescript:S1264'] = { level = 'on' },
            ['typescript:S5876'] = { level = 'on' },
            ['typescript:S6321'] = { level = 'on' },
            ['typescript:S6775'] = { level = 'on' },
            ['typescript:S3923'] = { level = 'on' },
            ['typescript:S1763'] = { level = 'on' },
            ['typescript:S6550'] = { level = 'on' },
            ['typescript:S5734'] = { level = 'on' },
            ['typescript:S5757'] = { level = 'on' },
            ['typescript:S5730'] = { level = 'on' },
            ['typescript:S6281'] = { level = 'on' },
            ['typescript:S6329'] = { level = 'on' },
            ['typescript:S5693'] = { level = 'on' },
            ['typescript:S6323'] = { level = 'on' },
            ['typescript:S5850'] = { level = 'on' },
            ['typescript:S6827'] = { level = 'on' },
            ['tssecurity:S6287'] = { level = 'on' },
            ['typescript:S3579'] = { level = 'on' },
            ['typescript:S4043'] = { level = 'on' },
            ['typescript:S3415'] = { level = 'on' },
            ['typescript:S2970'] = { level = 'on' },
            ['typescript:S5863'] = { level = 'on' },
            ['typescript:S1121'] = { level = 'on' },
            ['typescript:S4165'] = { level = 'on' },
            ['typescript:S5148'] = { level = 'on' },
            ['typescript:S6249'] = { level = 'on' },
            ['typescript:S6317'] = { level = 'on' },
            ['typescript:S6638'] = { level = 'on' },
            ['typescript:S1529'] = { level = 'on' },
            ['typescript:S1940'] = { level = 'on' },
            ['typescript:S2589'] = { level = 'on' },
            ['typescript:S1125'] = { level = 'on' },
            ['typescript:S6676'] = { level = 'on' },
            ['typescript:S6092'] = { level = 'on' },
            ['typescript:S6397'] = { level = 'on' },
            ['typescript:S5869'] = { level = 'on' },
            ['typescript:S5547'] = { level = 'on' },
            ['tsarchitecture:S7197'] = { level = 'on' },
            ['typescript:S101'] = { level = 'on' },
            ['typescript:S2094'] = { level = 'on' },
            ['typescript:S3776'] = { level = 'on' },
            ['typescript:S4030'] = { level = 'on' },
            ['typescript:S4143'] = { level = 'on' },
            ['typescript:S3981'] = { level = 'on' },
            ['typescript:S3616'] = { level = 'on' },
            ['typescript:S878'] = { level = 'on' },
            ['typescript:S6438'] = { level = 'on' },
            ['typescript:S3972'] = { level = 'on' },
            ['tssecurity:S6350'] = { level = 'on' },
            ['typescript:S2430'] = { level = 'on' },
            ['typescript:S4124'] = { level = 'on' },
            ['typescript:S7059'] = { level = 'on' },
            ['typescript:S6635'] = { level = 'on' },
            ['typescript:S3330'] = { level = 'on' },
            ['typescript:S2092'] = { level = 'on' },
            ['typescript:S6333'] = { level = 'on' },
            ['typescript:S4426'] = { level = 'on' },
            ['tssecurity:S3649'] = { level = 'on' },
            ['typescript:S4507'] = { level = 'on' },
            ['typescript:S1874'] = { level = 'on' },
            ['typescript:S6957'] = { level = 'on' },
            ['typescript:S3799'] = { level = 'on' },
            ['typescript:S6268'] = { level = 'on' },
            ['typescript:S5247'] = { level = 'on' },
            ['typescript:S5728'] = { level = 'on' },
            ['ruby:S1151'] = { level = 'on' },
            ['ruby:S131'] = { level = 'on' },
            ['ruby:S1821'] = { level = 'on' },
            ['ruby:S1479'] = { level = 'on' },
            ['ruby:S126'] = { level = 'on' },
            ['ruby:S3923'] = { level = 'on' },
            ['ruby:S1763'] = { level = 'on' },
            ['ruby:S1940'] = { level = 'on' },
            ['ruby:S101'] = { level = 'on' },
            ['ruby:S3776'] = { level = 'on' },
            ['ruby:S134'] = { level = 'on' },
            ['ruby:S1067'] = { level = 'on' },
            ['ruby:S104'] = { level = 'on' },
            ['ruby:S117'] = { level = 'on' },
            ['ruby:S138'] = { level = 'on' },
            ['ruby:S107'] = { level = 'on' },
            ['ruby:S2068'] = { level = 'on' },
            ['ruby:S1764'] = { level = 'on' },
            ['ruby:S103'] = { level = 'on' },
            ['ruby:S1066'] = { level = 'on' },
            ['ruby:S100'] = { level = 'on' },
            ['ruby:S1186'] = { level = 'on' },
            ['ruby:S4144'] = { level = 'on' },
            ['ruby:S4663'] = { level = 'on' },
            ['ruby:S108'] = { level = 'on' },
            ['ruby:S2757'] = { level = 'on' },
            ['ruby:S1314'] = { level = 'on' },
            ['ruby:S1110'] = { level = 'on' },
            ['ruby:S1862'] = { level = 'on' },
            ['ruby:ParsingError'] = { level = 'on' },
            ['ruby:S122'] = { level = 'on' },
            ['ruby:S1192'] = { level = 'on' },
            ['ruby:S105'] = { level = 'on' },
            ['ruby:S1451'] = { level = 'on' },
            ['ruby:S1134'] = { level = 'on' },
            ['ruby:S1135'] = { level = 'on' },
            ['ruby:S1871'] = { level = 'on' },
            ['ruby:S1172'] = { level = 'on' },
            ['ruby:S1481'] = { level = 'on' },
            ['ruby:S1145'] = { level = 'on' },
            ['ruby:S1313'] = { level = 'on' },
            ['ruby:S1656'] = { level = 'on' },

            -- ----------------------------------------------------------------------
            -- 🛠️ NEW / MISSING TYPESCRIPT RULES (Ensuring complete coverage for TS/TSX)
            -- ----------------------------------------------------------------------
            -- CRITICAL RULES
            ['typescript:S3785'] = { level = 'on' }, -- "in" should not be used with primitive types
            ['typescript:S3834'] = { level = 'on' }, -- "new" operator should not be used with Symbol and BigInt
            ['typescript:S4125'] = { level = 'on' }, -- "typeof" expressions should only be compared to valid values

            -- MAJOR RULES
            ['typescript:S3782'] = { level = 'on' }, -- Arguments to built-in functions should match documented types
            ['typescript:S3757'] = { level = 'on' }, -- Arithmetic operations should not result in "NaN"
            ['typescript:S3760'] = { level = 'on' }, -- Arithmetic operators should only have numbers as operands

            -- MINOR/CODE SMELL RULES
            ['typescript:S7753'] = { level = 'on' }, -- "indexOf()" and "lastIndexOf()" should be used instead of "findIndex()..."
            ['typescript:S7732'] = { level = 'on' }, -- "instanceof" should not be used with built-in objects
            ['typescript:S7784'] = { level = 'on' }, -- "structuredClone()" should be used instead of other deep cloning methods
            ['typescript:S7741'] = { level = 'on' }, -- "typeof" should not be used to check for "undefined"
            ['typescript:S2138'] = { level = 'on' }, -- "undefined" should not be assigned
            ['typescript:S1321'] = { level = 'on' }, -- "with" statements should not be used
            ['typescript:S1528'] = { level = 'on' }, -- Array constructors should not be used
            ['typescript:S7751'] = { level = 'on' }, -- Array flattening should use the native "flat()" method
            ['typescript:S7745'] = { level = 'on' }, -- Array length checks should not be used before "some()" and "every()"" calls
            ['typescript:S7752'] = { level = 'on' }, -- Array methods ".map().flat()" should be replaced with ".flatMap()"
            ['typescript:S7776'] = { level = 'on' }, -- Arrays used only for existence checks should be Sets (The specifically requested rule)

            -- MISC
            ['typescript:S7783'] = { level = 'on' }, -- "trimLeft()" and "trimRight()" should be replaced with "trimStart()..."
            ['typescript:S4326'] = { level = 'on' }, -- "await" should not be used redundantly
            ['typescript:S909'] = { level = 'on' }, -- "continue" should not be used
            ['tsarchitecture:S8134'] = { level = 'on' }, -- Architecture Directives to remove specific usages...

            -- ----------------------------------------------------------------------
            -- 💻 NEW JAVASCRIPT RULES (Ensuring parity with TS config)
            -- Note: Only rules that were *not* already in your original TS list are explicitly added here
            -- to cover the full set of rules from your initial JSON.
            -- ----------------------------------------------------------------------
            ['javascript:S1440'] = { level = 'on' }, -- "===" and "!==" should be used instead of "==" and "!="
            ['javascript:S3500'] = { level = 'on' }, -- "const" variables should not be reassigned
            ['javascript:S7753'] = { level = 'on' }, -- "indexOf()" and "lastIndexOf()" should be used instead of "findIndex()..."
            ['javascript:S7732'] = { level = 'on' }, -- "instanceof" should not be used with built-in objects
            ['javascript:S7784'] = { level = 'on' }, -- "structuredClone()" should be used instead of other deep cloning methods
            ['javascript:S7741'] = { level = 'on' }, -- "typeof" should not be used to check for "undefined"
            ['javascript:S2138'] = { level = 'on' }, -- "undefined" should not be assigned
            ['javascript:S3785'] = { level = 'on' }, -- "in" should not be used with primitive types
            ['javascript:S3834'] = { level = 'on' }, -- "new" operator should not be used with Symbol and BigInt
            ['javascript:S4125'] = { level = 'on' }, -- "typeof" expressions should only be compared to valid values
            ['javascript:S3782'] = { level = 'on' }, -- Arguments to built-in functions should match documented types
            ['javascript:S3757'] = { level = 'on' }, -- Arithmetic operations should not result in "NaN"
            ['javascript:S3760'] = { level = 'on' }, -- Arithmetic operators should only have numbers as operands
            ['javascript:S1528'] = { level = 'on' }, -- Array constructors should not be used
            ['javascript:S7751'] = { level = 'on' }, -- Array flattening should use the native "flat()" method
            ['javascript:S7745'] = { level = 'on' }, -- Array length checks should not be used before "some()..."
            ['javascript:S7752'] = { level = 'on' }, -- Array methods ".map().flat()" should be replaced with ".flatMap()"
            ['javascript:S7776'] = { level = 'on' }, -- Arrays used only for existence checks should be Sets
            ['javascript:S7783'] = { level = 'on' }, -- "trimLeft()" and "trimRight()" should be replaced with "trimStart()..."
            ['javascript:S4326'] = { level = 'on' }, -- "await" should not be used redundantly
            ['javascript:S909'] = { level = 'on' }, -- "continue" should not be used
            ['javascript:S1321'] = { level = 'on' }, -- "with" statements should not be used
            ['jsarchitecture:S8134'] = { level = 'on' }, -- Architecture Directives to remove specific usages...

            -- ----------------------------------------------------------------------
            -- 🚫 DEPRECATED/DISABLED RULES (Set to 'off' for clear intent)
            -- ----------------------------------------------------------------------
            ['typescript:S3973'] = { level = 'off' }, -- A conditionally executed single line... (DEPRECATED)
            ['typescript:S5743'] = { level = 'off' }, -- Allowing browsers to perform DNS prefetching... (DEPRECATED HOTSPOT)
            ['typescript:S1105'] = { level = 'off' }, -- An open curly brace should be located... (DEPRECATED)
            ['tsarchitecture:S7134'] = { level = 'off' }, -- Architectural constraints should not be violated (DEPRECATED)
            ['javascript:S1442'] = { level = 'off' }, -- "alert(...)" should not be used (DEPRECATED)
            ['javascript:S3973'] = { level = 'off' }, -- A conditionally executed single line... (DEPRECATED)
            ['javascript:S5743'] = { level = 'off' }, -- Allowing browsers to perform DNS prefetching... (DEPRECATED HOTSPOT)
            ['javascript:S1105'] = { level = 'off' }, -- An open curly brace should be located... (DEPRECATED)
          },
        },
      },
    }
  end,
}
