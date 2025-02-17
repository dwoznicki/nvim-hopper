local utils = require("bufhopper.utils")
local state = require("bufhopper.state")

local M = {}

---@class BufhopperFloatingWindow
---@field win integer
---@field buf integer
---@field open fun(): BufhopperFloatingWindow
---@field is_open fun(self: BufhopperFloatingWindow): boolean
---@field focus fun(self: BufhopperFloatingWindow): nil
---@field close fun(self: BufhopperFloatingWindow): nil
local FloatingWindow = {}
FloatingWindow.__index = FloatingWindow

function FloatingWindow.open()
  local float = {}
  setmetatable(float, FloatingWindow)
  local buf = vim.api.nvim_create_buf(false, true)
  float.buf = buf
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "bufhopperfloat", {buf = buf})
  local ui = vim.api.nvim_list_uis()[1]
  local win_height, win_width = utils.get_win_dimensions(0)
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "editor",
    width = win_width + 2, -- extra for borders
    height = win_height + 2, -- extra for borders
    row = 3,
    col = math.floor((ui.width - win_width) * 0.5),
    border = "none",
    focusable = false,
    -- title = " Buffers ",
    -- title_pos = "center",
    -- border = "rounded",
  }
  local win = vim.api.nvim_open_win(buf, false, win_config)
  float.win = win

  -- -- Close the float when the cursor leaves.
  -- vim.api.nvim_create_autocmd("WinLeave", {
  --   buffer = buf,
  --   once = true,
  --   callback = function()
  --     self:close()
  --   end,
  -- })

  -- -- Clear state when the buffer is deleted.
  -- vim.api.nvim_create_autocmd("BufWipeout", {
  --   buffer = buf,
  --   once = true,
  --   callback = function()
  --     state.clear_buflist()
  --     state.clear_float()
  --   end,
  -- })

  state.set_float(float)
  return float
end

function FloatingWindow:is_open()
  return self.win ~= nil and vim.api.nvim_win_is_valid(self.win)
end

function FloatingWindow:focus()
  vim.api.nvim_set_current_win(state.get_buflist().win)
end

function FloatingWindow:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  state.get_buflist():close()
  state.get_statline():close()
end

M.FloatingWindow = FloatingWindow

return M
