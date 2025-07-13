-- No imports!

local M = {}

---@param win integer
---@param buffers BufhopperBuffer[]
---@return BufhopperBuffer | nil, integer
function M.get_buf_key_under_cursor(win, buffers)
  local cursor_pos = vim.api.nvim_win_get_cursor(win)
  local buffer_idx = cursor_pos[1]
  ---@type BufhopperBuffer | nil
  local buf_key = buffers[buffer_idx]
  return buf_key, buffer_idx
end

---@return integer width, integer height
function M.get_win_dimensions()
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.ceil(ui.width * 0.5)
  -- For height, we'll try and choose a reasonable value without going over the available
  -- remaining space.
  local height = math.max(math.ceil(ui.height * 0.6), 16)
  return width, height
end

---@param list string[]
---@return table<string, true>
function M.set(list)
  local set = {}
  for _, value in ipairs(list) do
    set[value] = true
  end
  return set
end

---@generic T
---@param tbl `T`
---@return T
function M.readonly(tbl)
  local proxy = {}
  local metatbl = {
    __index = tbl,
    __newindex = function(t, key, val)
      error("Attempted to update a readonly table.", 2)
    end
  }
  setmetatable(proxy, metatbl)
  return proxy
end

---@generic T
---@param tbl T[]
---@return T[]
function M.sorted(tbl)
  ---@generic T
  local tbl_copy = {} ---@type T[]
  for i, item in ipairs(tbl) do
    tbl_copy[i] = item
  end
  table.sort(tbl_copy)
  return tbl_copy
end

---@param buf integer
---@param num_chars integer
---@return string
-- Clamp buffer value to given number of characters and return result.
-- Only one line is supported.
function M.clamp_buffer_value_chars(buf, num_chars)
  local value = vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] or ""
  if num_chars ~= nil and string.len(value) > num_chars then
    value = value:sub(1, num_chars)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {value})
  end
  return value
end

---@class hopper.ClampBufferValueLinesOpts
---@field exact? boolean If true, enforce exactly this number of lines, adding blanks if necessary.

---@param buf integer
---@param num_lines integer
---@param opts? hopper.ClampBufferValueLinesOpts
---@return string[]
-- Clamp buffer value to given number of lines and return result.
function M.clamp_buffer_value_lines(buf, num_lines, opts)
  opts = opts or {}
  local lines = vim.api.nvim_buf_get_lines(buf, 0, num_lines, false)
  if opts.exact then
    while #lines < num_lines do
      table.insert(lines, "")
      -- Call it after a while as a failsafe. If we get up to 1000 lines, something has gone wrong
      -- with this while loop.
      if #lines > 1000 then
        break
      end
    end
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return lines
end


return M
