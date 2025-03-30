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

return M
