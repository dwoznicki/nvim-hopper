local utils = require("bufhopper.utils")
local state = require("bufhopper.state")

local M = {}

---@class BufhopperStatusLine
---@field buf integer
---@field win integer
---@field mode BufhopperMode | nil
---@field attach fun(float: BufhopperFloatingWindow): BufhopperStatusLine
---@field draw fun(self: BufhopperStatusLine): nil
local StatusLine = {}
StatusLine.__index = StatusLine

function StatusLine.attach(float)
  local statline = {}
  setmetatable(statline, StatusLine)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("modifiable", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "bufhopperstatline", {buf = buf})
  statline.buf = buf
  local win_height, win_width = utils.get_win_dimensions(0)
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "win",
    win = float.win,
    width = win_width,
    height = 1,
    row = win_height,
    col = 1,
    border = "none",
    focusable = false,
  }
  local win = vim.api.nvim_open_win(buf, false, win_config)
  statline.win = win
  state.set_statline(statline)
  return statline
end

function StatusLine:draw()
  local mode = state.get_mode_manager().mode
  ---@type {name: string, row: integer, col_start: integer, col_end: integer}[]
  local hl_locs = {}
  ---@type string[]
  local buf_lines = {}
  if mode == "jump" then
    table.insert(buf_lines, "  Jump ")
    table.insert(hl_locs, {name = "BufhopperModeJump", row = 0, col_start = 1, col_end = 7})
  elseif mode == "open" then
    table.insert(buf_lines, "  Open ")
    table.insert(hl_locs, {name = "BufhopperModeOpen", row = 0, col_start = 1, col_end = 7})
  elseif mode == "delete" then
    table.insert(buf_lines, "  Delete ")
    table.insert(hl_locs, {name = "BufhopperModeDelete", row = 0, col_start = 1, col_end = 9})
  end

  vim.api.nvim_set_option_value("modifiable", true, {buf = self.buf})
  vim.api.nvim_buf_clear_namespace(self.buf, 0, 0, -1) -- clear highlights
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, buf_lines) -- draw lines
  for _, hl_loc in ipairs(hl_locs) do -- add highlights
    vim.api.nvim_buf_add_highlight(self.buf, 0, hl_loc.name, hl_loc.row, hl_loc.col_start, hl_loc.col_end)
  end
  vim.api.nvim_set_option_value("modifiable", false, {buf = self.buf})
  vim.cmd("redraw")
end

function StatusLine:close()
  vim.api.nvim_win_close(self.win, true)
end

M.StatusLine = StatusLine

return M
