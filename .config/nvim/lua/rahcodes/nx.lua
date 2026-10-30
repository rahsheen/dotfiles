-- Nx project lookup for the current buffer. The statusline calls this on every redraw,
-- so the result is cached per buffer and recomputed only when the buffer is renamed.
local M = {}

local function lookup(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local cached = vim.b[bufnr].nx_project
  if cached and cached.path == path then
    return cached
  end

  local result = { path = path, name = '' }
  local project_json = path ~= '' and vim.fs.find('project.json', { path = vim.fs.dirname(path), upward = true })[1]
  if project_json then
    result.root = vim.fs.dirname(project_json)
    local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(project_json), '\n'))
    result.name = ok and type(data) == 'table' and data.name or 'nx-pkg'
  end

  vim.b[bufnr].nx_project = result
  return result
end

---@param bufnr integer
---@return string|nil root directory of the Nx project, or nil outside one
function M.root(bufnr)
  return lookup(bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr).root
end

---@param bufnr integer
---@return string name of the Nx project, or '' outside one
function M.name(bufnr)
  return lookup(bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr).name
end

return M
