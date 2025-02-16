local M = {}

---@type BufhopperFloatState
M.state = {
  win = nil
}

---@return integer
function M.get_win()
  if M.state.win == nil then
    error("Bufhopper floating window not found!")
  end
  return M.state.win
end

---@param buf integer
function M.open_win(buf)
  local ui = vim.api.nvim_list_uis()[1]
  local _, win_width = M.get_win_dimensions(ui, 0)
  local buffers_win_config = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    -- height = buffers_height,
    height = 10,
    row = 3,
    col = math.floor((ui.width - win_width) * 0.5),
    title = " Buffers ",
    title_pos = "center",
    border = "rounded",
  }
  local win = vim.api.nvim_open_win(buf, true, buffers_win_config)
  M.state.win = win
  vim.api.nvim_set_option_value("cursorline", true, {win = win})
  vim.api.nvim_set_option_value("winhighlight", "CursorLine:BufhopperCursorLine", {win = win})
end

---@param ui table<string, unknown>
---@param num_buffer_rows integer
---@return integer, integer
function M.get_win_dimensions(ui, num_buffer_rows)
  local available_width = math.ceil(ui.width * 0.5)
  local available_height = ui.height - 6
  -- For buffer list height, we'll try and choose a reasonable height without going over the
  -- available remaining space.
  local buffers_height = math.max(math.min(num_buffer_rows, available_height), 20)
  return buffers_height, available_width
end

---@return boolean
function M.is_open()
  return M.state.win ~= nil and vim.api.nvim_win_is_valid(M.state.win)
end

return M
