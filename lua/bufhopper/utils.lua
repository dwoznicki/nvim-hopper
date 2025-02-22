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

---@param num_buffer_rows integer
---@return integer, integer
function M.get_win_dimensions(num_buffer_rows)
  local ui = vim.api.nvim_list_uis()[1]
  local available_width = math.ceil(ui.width * 0.5)
  local available_height = ui.height - 6
  -- For buffer list height, we'll try and choose a reasonable height without going over the
  -- available remaining space.
  local buffers_height = math.max(math.min(num_buffer_rows, available_height), 20)
  return 16, available_width
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

return M
