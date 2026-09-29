local M = {}
function M.load(path)
  local ok, value = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
  end)
  if not ok or type(value) ~= 'table' or type(value.done) ~= 'table' then
    return { done = {} }
  end
  return value
end
function M.save(path, value)
  local ok, err = pcall(function()
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    local tmp = path .. '.tmp'
    assert(vim.fn.writefile({ vim.json.encode(value) }, tmp) == 0)
    assert(vim.fn.rename(tmp, path) == 0)
  end)
  return ok, err
end
return M
