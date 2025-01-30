local M = {}

M.utils = {}

M.uuid = {}

M.uuid.new = function()
  return vim.fn.systemlist("uuidgen | tr -d '\\n'")
end

M.ui = {}

M.ui.insert_text = function(str)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row_index, col_index = cursor[1]-1, cursor[2]
  vim.api.nvim_buf_set_text(0, row_index, col_index, row_index, col_index, str)
end

M.ui.get_selected_text = function()
  local s = M.ui.get_selection()
  return vim.api.nvim_buf_get_text(0, s.start_line-1, s.start_col-1, s.end_line-1, s.end_col, {})
end

---@class ak.Selection
---@field buf number
---@field start_line number
---@field start_col number
---@field end_line number
---@field end_col number

--- get buffer and location of current selection
---@return ak.Selection
M.ui.get_selection = function()
  local vstart = vim.fn.getpos("'<")
  local vend = vim.fn.getpos("'>")

  -- return actual line numbers not indices
  return {
    buf = vstart[1],
    start_line = vstart[2],
    start_col = vstart[3],
    end_line = vend[2],
    end_col = vend[3],
  }
end

--- replace currently selected text with str
---@param str string|string[]
M.ui.replace_selection = function(str)
  local s = M.ui.get_selection()

  if type(str) == "string" then
    if string.match(str, '\\n') then
      str = vim.split(str, '\n', {plain=true})
    else
      str = { str }
    end
  end

  vim.api.nvim_buf_set_text(s.buf, s.start_line-1, s.start_col-1, s.end_line-1, s.end_col, str)
end

M.url = {}

M.url.encode = function(str)
  if type(str) ~= "number" then
    str = str:gsub("\r?\n", "\r\n")
    str = str:gsub("([^%w%-%.%_%~ ])", function(c)
      return string.format("%%%02X", c:byte())
    end)
    str = str:gsub(" ", "+")
    return str
  else
    return str
  end
end

M.ui.url = {}

M.ui.url.encode = function ()
  local text = M.ui.get_selected_text()
  local flattened = table.concat(text, "\n")
  local encoded = M.url.encode(flattened)
  M.ui.replace_selection(encoded)
end

M.ui.base64 = {}

M.ui.base64.encode = function ()
  local text = M.ui.get_selected_text()
  local flattened = table.concat(text, "\n")
  local base64 = vim.base64.encode(flattened)
  if base64 ~= nil then
    M.ui.replace_selection(base64)
  end
end

M.ui.base64.decode = function ()
  local text = M.ui.get_selected_text()
  local flattened = table.concat(text, "\n")
  local base64 = vim.base64.decode(flattened)
  if base64 ~= nil then
    M.ui.replace_selection(base64)
  end
end

M.base64url = {}

---@param str string
---@return string?
M.base64url.encode = function (str)
  return vim.fn.system("basenc --base64url -w0", str)
end

---@param str string
---@return string?
M.base64url.decode = function (str)
  local s = vim.fn.system("basenc --ignore-garbage --decode --base64url -w0", str)
  -- TODO: find an better solution to this
  s = s:gsub("basenc: invalid input\n", "")
  return s
end

M.ui.base64url = {}

M.ui.base64url.decode = function ()
  local text = M.ui.get_selected_text()
  local flattened = table.concat(text, "\n")

  local base64url = M.base64url.decode(flattened)
  if base64url ~= nil then
    M.ui.replace_selection(base64url)
  end
end

M.ui.base64url.encode = function ()
  local text = M.ui.get_selected_text()
  local flattened = table.concat(text, "")
  flattened = vim.trim(flattened);
  local base64url = M.base64url.encode(flattened)
  if base64url ~= nil then
    M.ui.replace_selection(base64url)
  end
end

M.ui.jwt = {}

--TODO: https://www.rfc-editor.org/rfc/rfc7515
--TODO: https://www.rfc-editor.org/rfc/rfc7515#appendix-C
--TODO: https://www.rfc-editor.org/rfc/rfc7515#section-3.2
--- Decodes an JWT token and replaces it inplace
---@param command_args vim.api.keyset.create_user_command.command_args
M.ui.jwt.decode = function(command_args)
  -- local lines = vim.api.nvim_buf_get_text(0, command_args.line1, command_args.range, command_args.line2, 0, {})
  local lines = M.ui.get_selected_text()
  local jwt = table.concat(lines)
  local parts = vim.split(jwt, '.', {plain=true})
  local jsons = {}

  table.insert(jsons, M.base64url.decode(parts[1]))
  table.insert(jsons, M.base64url.decode(parts[2]))
  table.insert(jsons, parts[3])
  M.ui.replace_selection(jsons)
end


M.fs = {}

--- Find the root directory based on an indicating pattern
M.fs.find_root_dir = function(source, indicator_pattern)
  local fn_match_file = function (filename)
    local match = string.match(filename, indicator_pattern)
    if match then
      return true
    end
    return false
  end
  local path;
  local matches = vim.fs.find(fn_match_file, {
    path = source,
    upward = true,
    type = "directory"
  })
  if matches and #matches > 0 then
    path = vim.fn.fnamemodify(matches[1], ":p:h:h")
  end

  return path
end

-- Find git directory for current file
M.fs.get_git_dir = function ()
  local git_path = M.fs.find_root_dir(vim.fn.expand('%:p:h'), ".git")
  return git_path
end

return M
