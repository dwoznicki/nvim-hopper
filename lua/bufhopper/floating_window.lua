local utils = require("bufhopper.utils")
local state = require("bufhopper.state")

local M = {}

---@class BufhopperFloatingWindow
---@field win integer | nil
---@field new fun(): BufhopperFloatingWindow
---@field open fun(self: BufhopperFloatingWindow): nil
---@field is_open fun(self: BufhopperFloatingWindow): boolean
---@field close fun(self: BufhopperFloatingWindow): nil
local FloatingWindow = {}
FloatingWindow.__index = FloatingWindow

function FloatingWindow.new()
  local float = {}
  setmetatable(float, FloatingWindow)
  return float
end

function FloatingWindow:open()
  if self:is_open() then
    vim.api.nvim_set_current_win(self.win)
    return
  end
  local buflist = state.get_buflist()
  local ui = vim.api.nvim_list_uis()[1]
  local _, win_width = utils.get_win_dimensions(0)
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
  local win = vim.api.nvim_open_win(buflist.buf, true, buffers_win_config)
  vim.api.nvim_set_option_value("cursorline", true, {win = win})
  vim.api.nvim_set_option_value("winhighlight", "CursorLine:BufhopperCursorLine", {win = win})
  self.win = win
  -- Close the float when the cursor leaves.
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buflist.buf,
    once = true,
    callback = function()
      self:close()
    end,
  })
  -- Clear state when the buffer is deleted.
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buflist.buf,
    callback = function()
      state.clear_buflist()
      state.clear_float()
    end,
  })
end

function FloatingWindow:is_open()
  return self.win ~= nil and vim.api.nvim_win_is_valid(self.win)
end

function FloatingWindow:close()
  if not self:is_open() then
    return
  end
  vim.api.nvim_win_close(self.win, true)
end

M.FloatingWindow = FloatingWindow

-- ---@param buf integer
-- ---@param ui table<string, unknown>
-- ---@return integer
-- function M.create_win(buf, ui)
--   local _, win_width = M.get_win_dimensions(ui, 0)
--   local buffers_win_config = {
--     style = "minimal",
--     relative = "editor",
--     width = win_width,
--     -- height = buffers_height,
--     height = 10,
--     row = 3,
--     col = math.floor((ui.width - win_width) * 0.5),
--     title = " Buffers ",
--     title_pos = "center",
--     border = "rounded",
--   }
--   local win = vim.api.nvim_open_win(buf, true, buffers_win_config)
--   vim.api.nvim_set_option_value("cursorline", true, {win = win})
--   vim.api.nvim_set_option_value("winhighlight", "CursorLine:BufhopperCursorLine", {win = win})
--   return win
-- end

-- ---@return boolean
-- function M.is_open()
--   return M.state.win ~= nil and vim.api.nvim_win_is_valid(M.state.win)
-- end

return M
