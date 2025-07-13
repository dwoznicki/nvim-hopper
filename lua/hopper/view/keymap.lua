local utils = require("hopper.utils")
local quickfile = require("hopper.quickfile")
local projects = require("hopper.projects")

---@alias hopper.HighlightLocation {name: string, row: integer, col_start: integer, col_end: integer}

local ns_id = vim.api.nvim_create_namespace("hopper.KeymapFloatingWindow")
--TODO: Make this configurable.
local num_chars = 2
local loop = vim.uv or vim.loop

local M = {}

---@class hopper.KeymapFloatingWindow
---@field project hopper.Project | nil
---@field path string
---@field keymap string
---@field buf integer
---@field win integer
---@field win_width integer
---@field conflicting_mapping hopper.FileMapping | nil
---@field go_back_callback function | nil
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
  float.project = nil
  float.path = ""
  float.keymap = ""
  float.buf = -1
  float.win = -1
  float.win_width = -1
  float.conflicting_mapping = nil
  float.go_back_callback = nil
end

---@class hopper.OpenNewKeymapFloatOptions
---@field project hopper.Project | string | nil
---@field go_back function | nil

---@param path string
---@param opts? hopper.OpenNewKeymapFloatOptions
function KeymapFloatingWindow:open(path, opts)
  opts = opts or {}
  if opts.project then
    self.project = projects.resolve_project(opts.project)
  else
    self.project = projects.current_project()
  end
  self.go_back_callback = opts.go_back

  local ui = vim.api.nvim_list_uis()[1]
  local win_width, _ = utils.get_win_dimensions()
  self.win_width = win_width

  self.path = quickfile.truncate_path(path, win_width)

  local datastore = require("hopper.db").datastore()
  local existing_file = datastore:get_file_by_path(self.project.name, path)
  local existing_keymap = nil ---@type string | nil
  if existing_file ~= nil then
    existing_keymap = existing_file.keymap
  end
  self.keymap = existing_keymap or ""

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "prompt", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("buflisted", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "HopperKeymapFloat", {buf = buf})
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = 3,
    row = 3,
    col = math.floor((ui.width - win_width) * 0.5),
    focusable = true,
    title = " Enter a keymap ",
    title_pos = "center",
    border = "rounded",
  }
  -- Don't show the prompt text.
  vim.fn.prompt_setprompt(buf, "")
  -- If there is an existing mapping, pre-populate it.
  -- Otherwise, start in insert mode so user can immediately start typing.
  if existing_keymap then
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, {existing_keymap})
  else
    vim.api.nvim_create_autocmd("BufEnter", {
      buffer = buf,
      callback = function()
        vim.cmd("startinsert")
      end,
    })
  end
  local win = vim.api.nvim_open_win(buf, true, win_config)
  self.buf = buf
  self.win = win

  self:_attach_event_handlers()

  self:draw()
end

function KeymapFloatingWindow:draw()
  vim.api.nvim_buf_clear_namespace(self.buf, ns_id, 0, -1)

  local value = vim.api.nvim_buf_get_lines(self.buf, 0, 1, false)[1] or ""
  local used = string.len(value)
  vim.api.nvim_buf_set_extmark(self.buf, ns_id, 0, 0, {
    virt_text = {
      {string.format("%d/%d", used, num_chars), "Comment"}
    },
    virt_text_pos = "right_align",
  })

  local keymap_indexes = quickfile.keymap_location_in_path(self.path, self.keymap, {missing_behavior = "nearby"})
  local path_line = quickfile.highlight_path_virtual_text(self.path, self.keymap, keymap_indexes)
  local help_line = {{"  "}} ---@type string[][]
  if self:_keymap_ok() then
    table.insert(help_line, {"󰌑 ", "Function"})
    table.insert(help_line, {" Confirm"})
  else
    table.insert(help_line, {"󰌑  Confirm", "Comment"})
  end
  table.insert(help_line, {"  "})
  if string.len(value) < 1 then
    table.insert(help_line, {"󰌒 ", "String"})
    table.insert(help_line, {" Suggest"})
  else
    table.insert(help_line, {"󰌒  Suggest", "Comment"})
  end
  if self.go_back_callback ~= nil then
    table.insert(help_line, {"  "})
    local curr_mode = vim.api.nvim_get_mode().mode
    if curr_mode == "n" then
      table.insert(help_line, {"󰁮 ", "Warning"})
      table.insert(help_line, {" Back"})
    else
      table.insert(help_line, {"󰁮  Back", "Comment"})
    end
  end

  local error_line = nil ---@type string[][]
  local next_win_height ---@type integer
  if self.conflicting_mapping ~= nil then
    local errmsg = "Conflicting mapping found: "
    local conflicting_path = quickfile.truncate_path(self.conflicting_mapping.path, self.win_width - vim.fn.strdisplaywidth(errmsg) - 2)
    next_win_height = 4
    error_line = {
      {errmsg .. conflicting_path, "Error"},
    }
  else
    next_win_height = 3
  end
  if vim.api.nvim_win_get_height(self.win) ~= next_win_height then
    vim.api.nvim_win_set_height(self.win, next_win_height)
  end

  local virtual_lines = {} ---@type string[][][]
  table.insert(virtual_lines, path_line)
  if error_line ~= nil then
    table.insert(virtual_lines, error_line)
  end
  table.insert(virtual_lines, help_line)

  vim.api.nvim_buf_set_extmark(self.buf, ns_id, 0, 0, {
    virt_lines = virtual_lines,
    virt_lines_above = false,
    virt_lines_leftcol = false,
  })
end

function KeymapFloatingWindow:confirm()
  if not self:_keymap_ok() then
    return
  end
  local datastore = require("hopper.db").datastore()
  datastore:set_file(self.project.name, self.path, self.keymap)
  self:close()
end

function KeymapFloatingWindow:suggest_keymap()
  local value = vim.api.nvim_buf_get_lines(self.buf, 0, 1, false)[1] or ""
  if string.len(value) > 0 then
    return
  end
  local datastore = require("hopper.db").datastore()
  local assigned_keymaps = utils.set(datastore:list_keymaps(self.project.name))
  local allowed_keys = utils.set(require("hopper.options").options().files.keyset)
  local suggested_keymap = quickfile.keymap_for_path(self.path, 4, allowed_keys, assigned_keymaps)
  vim.api.nvim_buf_set_lines(self.buf, 0, 1, false, {suggested_keymap})
end

function KeymapFloatingWindow:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  KeymapFloatingWindow._reset(self)
end

function KeymapFloatingWindow:_attach_event_handlers()
  local buf = self.buf
  vim.keymap.set(
    {"i", "n"},
    "<cr>",
    function()
      self:confirm()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  -- Close on q keypress.
  vim.keymap.set(
    "n",
    "q",
    function()
      self:close()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  -- Close on esc keypress.
  vim.keymap.set(
    "n",
    "<esc>",
    function()
      self:close()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  -- Fill keymap suggestion on tab keypress.
  vim.keymap.set(
    {"i", "n"},
    "<tab>",
    function()
      self:suggest_keymap()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  if self.go_back_callback ~= nil then
    -- Go back to previous view on backspace keypress.
    vim.keymap.set(
      "n",
      "<bs>",
      function()
        self.go_back_callback()
      end,
      {noremap = true, silent = true, nowait = true, buffer = buf}
    )
  end

  vim.api.nvim_create_autocmd({"TextChangedI", "TextChanged"}, {
    buffer = buf,
    callback = function()
      -- Clear the `modified` flag for prompt so we can close without saving.
      vim.bo[buf].modified = false
      local value = utils.clamp_buffer_value(buf, num_chars)
      self.keymap = value
      self:draw()
      local float = self
      loop.new_timer():start(0, 0, function()
        local datastore = require("hopper.db").datastore()
        local mapping = datastore:get_file_by_keymap(float.project.name, float.keymap)
        vim.schedule(function()
          if mapping ~= nil and mapping.path == float.path then
            mapping = nil
          end
          local prev_mapping = float.conflicting_mapping
          float.conflicting_mapping = mapping
          if (prev_mapping == nil and mapping ~= nil) or (prev_mapping ~= nil and mapping == nil) then
            float:draw()
          end
        end)
      end)
    end,
  })

  vim.api.nvim_create_autocmd({"BufWinLeave", "WinLeave"}, {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        self:close()
      end)
    end,
  })
end

---@return boolean
function KeymapFloatingWindow:_keymap_ok()
  if string.len(self.keymap) < num_chars then
    -- Keymap must have exactly specified number of characters.
    return false
  end
  if self.conflicting_mapping ~= nil then
    -- Keymaap cannot have a known conflict.
    return false
  end
  return true
end

local _float = nil ---@type hopper.KeymapFloatingWindow | nil

---@return hopper.KeymapFloatingWindow
function M.float()
  if _float == nil then
    _float = KeymapFloatingWindow._new()
  end
  return _float
end

return M
