local utils = require("hopper.utils")
local quickfile = require("hopper.quickfile")

local ns_id = vim.api.nvim_create_namespace("hopper.KeymapFloatingWindow")

local M = {}

---@class hopper.FilesFloatingWindow
---@field project string
---@field mappings hopper.Mapping[]
---@field visible_mappings hopper.Mapping[]
---@field buf integer
---@field win integer
---@field win_width integer
local FilesFloatingWindow = {}
FilesFloatingWindow.__index = FilesFloatingWindow
M.FilesFloatingWindow = FilesFloatingWindow

---@return hopper.FilesFloatingWindow
function FilesFloatingWindow._new()
  local float = {}
  setmetatable(float, FilesFloatingWindow)
  FilesFloatingWindow._reset(float)
  return float
end

---@param float hopper.FilesFloatingWindow
function FilesFloatingWindow._reset(float)
  float.project = ""
  float.mappings = {}
  float.visible_mappings = {}
  float.buf = -1
  float.win = -1
  float.win_width = -1
end

---@param project string
---@param mappings hopper.Mapping[]
function FilesFloatingWindow:open(project, mappings)
  local ui = vim.api.nvim_list_uis()[1]
  local win_width, win_height = utils.get_win_dimensions()
  self.win_width = win_width

  self.project = project
  self.mappings = mappings
  self.visible_mappings = mappings

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("buflisted", false, {buf = buf})
  vim.api.nvim_set_option_value("modifiable", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "HopperMappingFloat", {buf = buf})
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = 3,
    col = math.floor((ui.width - win_width) * 0.5),
    focusable = true,
    title = " Mappings ",
    title_pos = "center",
    border = "rounded",
  }
  -- -- Don't show the prompt text.
  -- vim.fn.prompt_setprompt(buf, "")
  -- -- If there is an existing mapping, pre-populate it.
  -- -- Otherwise, start in insert mode so user can immediately start typing.
  -- if existing_keymap then
  --   vim.api.nvim_buf_set_lines(buf, 0, 1, false, {existing_keymap})
  -- else
  --   vim.api.nvim_create_autocmd("BufEnter", {
  --     buffer = buf,
  --     callback = function()
  --       vim.cmd("startinsert")
  --     end,
  --   })
  -- end
  local win = vim.api.nvim_open_win(buf, true, win_config)
  self.buf = buf
  self.win = win

  self:_attach_event_handlers()

  self:draw()
end

function FilesFloatingWindow:draw()
  local lines = {} ---@type string[]
  local highlights = {} ---@type hopper.HighlightLocation[]

  for _, mapping in ipairs(self.visible_mappings) do
    local keymap_indexes = quickfile.keymap_location_in_path(mapping.path, mapping.keymap, {missing_behavior = "nearby"})
    table.insert(lines, mapping.path)
  end

  vim.api.nvim_set_option_value("modifiable", true, {buf = self.buf})
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, {}) -- clear lines
  vim.api.nvim_buf_clear_namespace(self.buf, 0, 0, -1) -- clear highlights
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines) -- draw lines
  for _, hl in ipairs(highlights) do -- add highlights
    vim.api.nvim_buf_add_highlight(self.buf, 0, hl.name, hl.row, hl.col_start, hl.col_end)
  end
  vim.api.nvim_set_option_value("modifiable", false, {buf = self.buf})
end

function FilesFloatingWindow:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  FilesFloatingWindow._reset(self)
end

function FilesFloatingWindow:_attach_event_handlers()
  local buf = self.buf

  -- vim.keymap.set(
  --   {"i", "n"},
  --   "<cr>",
  --   function()
  --     self:confirm()
  --   end,
  --   {noremap = true, silent = true, nowait = true, buffer = buf}
  -- )

  -- -- Close on "q" keypress.
  -- vim.keymap.set(
  --   "n",
  --   "q",
  --   function()
  --     self:close()
  --   end,
  --   {noremap = true, silent = true, nowait = true, buffer = buf}
  -- )

  -- Close on "<esc>" keypress.
  vim.keymap.set(
    "n",
    "<esc>",
    function()
      self:close()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )

  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      self:close()
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      self:close()
    end,
  })
end

local _float = nil ---@type hopper.FilesFloatingWindow | nil

---@return hopper.FilesFloatingWindow
function M.float()
  if _float == nil then
    _float = FilesFloatingWindow._new()
  end
  return _float
end

return M
