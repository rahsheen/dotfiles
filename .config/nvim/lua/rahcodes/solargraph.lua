local lsp = require 'lspconfig'
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())
local handlers = {
  ['textDocument/publishDiagnostics'] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
    virtual_text = true,
  }),
}

lsp.solargraph.setup {
  capabilities = capabilities,
  handlers = handlers,
  cmd = { os.getenv 'HOME' .. '/.asdf/shims/solargraph', 'stdio' },
  root_dir = lsp.util.root_pattern('Gemfile', '.git', '.'),
  filetypes = { 'ruby', 'rakefile' },
  settings = {
    solargraph = {
      autoformat = true,
      completion = true,
      diagnostic = true,
      folding = true,
      references = true,
      rename = true,
      symbols = true,
    },
  },
}
-- Setup Rubocop for linting with bundler execution
-- lsp.rubocop.setup {
--   cmd = { 'bundle', 'exec', 'rubocop', '--format', 'json', '--force-exclusion' },
--   root_dir = lsp.util.root_pattern('Gemfile', '.git', '.'),
--   filetypes = { 'ruby', 'rakefile' },
--   settings = {
--     rubocop = {
--       useBundler = true,
--       bundlerPath = 'bundle',
--       configFile = '.rubocop.yml',
--     },
--   },
-- }
