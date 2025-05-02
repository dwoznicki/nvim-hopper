local utils = require("hopper.utils")

---@alias hopper.HighlightLocation {name: string, row: integer, col_start: integer, col_end: integer}

local M = {}

---@class hopper.KeymapFloatingWindow
---@field project string
---@field path string
---@field keymap string
---@field container_buf integer
---@field container_win integer
---@field input_buf integer
---@field input_win integer
---@field helper_buf integer
---@field helper_win integer
---@field win_width integer
local KeymapFloatingWindow = {}
KeymapFloatingWindow.__index = KeymapFloatingWindow
M.KeymapFloatingWindow = KeymapFloatingWindow

---@return hopper.KeymapFloatingWindow
function KeymapFloatingWindow._new()
  local float = {}
  setmetatable(float, KeymapFloatingWindow)
  KeymapFloatingWindow._reset(float)
  return float
end

---@param float hopper.KeymapFloatingWindow
function KeymapFloatingWindow._reset(float)
  float.project = ""
  float.path = ""
  float.keymap = ""
  float.container_buf = -1
  float.container_win = -1
  float.input_buf = -1
  float.input_win = -1
  float.helper_buf = -1
  float.helper_win = -1
  float.win_width = -1
end

---@param project string
---@param path string
---@param existing_keymap string | nil
function KeymapFloatingWindow:open(project, path, existing_keymap)
  self.project = project
  self.path = path
  self.keymap = existing_keymap or ""

  local ui = vim.api.nvim_list_uis()[1]
  local win_width, _ = utils.get_win_dimensions()
  self.win_width = win_width

  -- Create the container window.
  local container_buf, container_win = KeymapFloatingWindow._open_container(ui, win_width)
  self.container_buf = container_buf
  self.container_win = container_win

  -- Create the input window.
  local input_buf, input_win = KeymapFloatingWindow._open_input(container_win, win_width)
  self.input_buf = input_buf
  self.input_win = input_win

  -- Create the helper window.
  local helper_buf, helper_win = KeymapFloatingWindow._open_helper(container_win, win_width)
  self.helper_buf = helper_buf
  self.helper_win = helper_win

  self:_apply_event_handlers()
end

function KeymapFloatingWindow:draw()
  local lines = {} ---@type string[]
  local hls = {} ---@type hopper.HighlightLocation[]

  table.insert(lines, string.rep("─", self.win_width))
  table.insert(lines, "Enter a two character keymap.")
  table.insert(hls, {name = "hopper.hl.SecondaryText", row = 1, col_start = 1, col_end = 29})
  table.insert(lines, self.path)

  vim.api.nvim_buf_clear_namespace(self.helper_buf, 0, 0, -1) -- clear highlights
  vim.api.nvim_buf_set_lines(self.helper_buf, 0, -1, false, lines)
  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(self.helper_buf, 0, hl.name, hl.row, hl.col_start, hl.col_end)
  end
end

function KeymapFloatingWindow:confirm()
  local datastore = require("hopper.db").datastore()
  datastore.set_quick_file(self.project, self.path, self.keymap)
end

function KeymapFloatingWindow:close()
  if vim.api.nvim_win_is_valid(self.container_win) then
    vim.api.nvim_win_close(self.container_win, true)
  end
  KeymapFloatingWindow._reset(self)
end

---@param ui any
---@param win_width integer
---@return integer buf, integer win
function KeymapFloatingWindow._open_container(ui, win_width)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = 2,
    row = 3,
    col = math.floor((ui.width - win_width) * 0.5),
    -- border = "none",
    focusable = false,
    title = " Keymap ",
    title_pos = "center",
    border = "rounded",
  }
  local win = vim.api.nvim_open_win(buf, false, win_config)
  return buf, win
end

---@param container_win integer
---@param win_width integer
---@return integer buf, integer win
function KeymapFloatingWindow._open_input(container_win, win_width)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "BufhopperFloat", {buf = buf})
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "win",
    win = container_win,
    width = win_width,
    -- height = win_height - 1, -- space for status line
    height = 1,
    row = 0,
    col = 0,
    border = "none",
    focusable = true,
  }
  local win = vim.api.nvim_open_win(buf, true, win_config)
  return buf, win
end

---@param container_win integer
---@param win_width integer
---@return integer buf, integer win
function KeymapFloatingWindow._open_helper(container_win, win_width)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("modifiable", false, {buf = buf})
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "win",
    win = container_win,
    width = win_width,
    height = 3,
    row = 1,
    col = 0,
    border = "none",
    focusable = false,
  }
  local win = vim.api.nvim_open_win(buf, false, win_config)
  return buf, win
end

function KeymapFloatingWindow:_apply_event_handlers()
  local buf = self.input_buf
  vim.keymap.set(
    {"i", "n"},
    "<cr>",
    function()
      self:confirm()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  -- Close on "q" keypress.
  vim.keymap.set(
    "n",
    "q",
    function()
      self:close()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  -- Close on "<esc>" keypress.
  vim.keymap.set(
    "n",
    "<esc>",
    function()
      self:close()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  -- require("bufhopper.integrations").clear_whichkey(buf)

  -- Close the float when the cursor leaves.
  -- vim.api.nvim_create_autocmd("WinLeave", {
  --   buffer = buf,
  --   once = true,
  --   callback = function()
  --     state.get_floating_window():close()
  --   end,
  -- })
  -- vim.api.nvim_create_autocmd("BufWipeout", {
  --   buffer = buf,
  --   once = true,
  --   callback = function()
  --     state.get_floating_window():close()
  --   end,
  -- })
end

local keymap_float = nil ---@type hopper.KeymapFloatingWindow | nil
---@return hopper.KeymapFloatingWindow
function M.keymap_float()
  if keymap_float == nil then
    keymap_float = KeymapFloatingWindow._new()
  end
  return keymap_float
end

return M

