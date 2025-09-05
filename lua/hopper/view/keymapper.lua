local utils = require("hopper.utils")
local keymaps = require("hopper.keymaps")
local projects = require("hopper.projects")
local options = require("hopper.options")

local loop = vim.uv or vim.loop

---@alias hopper.HighlightLocation {name: string, row: integer, col_start: integer, col_end: integer}

---@alias hopper.KeymapperValidationCode "keymap_conflict" | "keymap_will_be_deleted"

---@class hopper.KeymapperValidation
---@field code hopper.KeymapperValidationCode
---@field message string

local M = {}

---@class hopper.Keymapper
---@field project hopper.Project | nil
---@field path string
---@field keymap string
---@field is_open boolean
---@field existing_file hopper.FileKeymap | nil
---@field buf integer
---@field win integer
---@field win_width integer
---@field footer_buf integer
---@field footer_win integer
---@field validation hopper.KeymapperValidation | nil
---@field suggested_keymap string | nil
---@field keymap_length integer | nil
---@field actions table<hopper.KeymapperViewAction, string[]>
---@field on_keymap_set fun(form: hopper.Keymapper) | nil
---@field on_back fun(form: hopper.Keymapper) | nil
local Keymapper = {}
Keymapper.__index = Keymapper
M.Keymapper = Keymapper

Keymapper.default_win_height = 4
Keymapper.default_footer_win_height = 2
Keymapper.ns = vim.api.nvim_create_namespace("hopper.Keymapper")
Keymapper.footer_ns = vim.api.nvim_create_namespace("hopper.KeymapperFooter")

---@return hopper.Keymapper
function Keymapper._new()
  local form = {}
  setmetatable(form, Keymapper)
  Keymapper._reset(form)
  return form
end

---@param instance hopper.Keymapper
function Keymapper._reset(instance)
  instance.project = nil
  instance.path = ""
  instance.keymap = ""
  instance.existing_file = nil
  instance.is_open = false
  instance.buf = -1
  instance.win = -1
  instance.win_width = -1
  instance.footer_buf = -1
  instance.footer_win = -1
  instance.validation = nil
  instance.suggested_keymap = nil
  instance.keymap_length = -1
  instance.actions = {}
  instance.on_keymap_set = nil
  instance.on_back = nil
end

---@class hopper.KeymapperOpenOptions
---@field project hopper.Project | string | nil
---@field keymap_length integer | nil
---@field on_keymap_set fun(float: hopper.Keymapper) | nil
---@field on_back fun(float: hopper.Keymapper) | nil
---@field width integer | decimal | nil

---@param path string
---@param opts? hopper.KeymapperOpenOptions
function Keymapper:open(path, opts)
  opts = opts or {}
  local full_options = options.options()
  self.project = projects.ensure_project(opts.project)
  self.keymap_length = opts.keymap_length or full_options.keymapping.length
  self.actions = full_options.actions.keymapper

  self.on_keymap_set = opts.on_keymap_set
  self.on_back = opts.on_back

  local ui = vim.api.nvim_list_uis()[1]
  local opts_width = opts.width or full_options.float.width
  local win_width, _ = utils.get_win_dimensions(opts_width, 0)
  self.win_width = win_width

  self.path = keymaps.truncate_path(path, win_width)

  local datastore = require("hopper.db").datastore()
  local existing_file = datastore:get_file_keymap_by_path(self.project.name, path)
  local existing_keymap = nil ---@type string | nil
  if existing_file ~= nil then
    existing_keymap = existing_file.keymap
  end
  self.keymap = existing_keymap or ""
  self.existing_file = existing_file

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "prompt", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("buflisted", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "hopperfloat", {buf = buf})
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = self.default_win_height,
    row = 3,
    col = math.floor((ui.width - win_width) * 0.5),
    focusable = true,
    title = " Keymap ",
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

  local footer_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = footer_buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = footer_buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = footer_buf})
  vim.api.nvim_buf_set_lines(footer_buf, 0, -1, false, {""})
  ---@type vim.api.keyset.win_config
  local footer_win_config = {
    style = "minimal",
    relative = "editor",
    width = win_config.width,
    height = self.default_footer_win_height,
    row = win_config.row + win_config.height - 1,
    col = win_config.col + 1,
    focusable = false,
    border = "none",
    zindex = 51, -- Just enough to site on top of the main window.
  }
  local footer_win = vim.api.nvim_open_win(footer_buf, false, footer_win_config)

  self.buf = buf
  self.win = win
  self.footer_buf = footer_buf
  self.footer_win = footer_win
  self.is_open = true

  self:_attach_event_handlers()

  self:draw()

  vim.schedule(function()
    self:_suggest_keymap()
  end)
end

function Keymapper:draw()
  self:draw_main()
  self:draw_footer()
end

function Keymapper:draw_main()
  vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1)

  local value = vim.api.nvim_buf_get_lines(self.buf, 0, 1, false)[1] or ""
  local used = string.len(value)
  vim.api.nvim_buf_set_extmark(self.buf, self.ns, 0, 0, {
    virt_text = {
      {string.format("%d/%d", used, self.keymap_length), "hopper.DisabledText"}
    },
    virt_text_pos = "right_align",
  })

  if self.suggested_keymap ~= nil and string.len(self.suggested_keymap) > 0 and string.len(value) < 1 then
    vim.api.nvim_buf_set_extmark(self.buf, self.ns, 0, 0, {
      virt_text = {{self.suggested_keymap, "hopper.DisabledText"}},
      virt_text_pos = "overlay",
    })
  end

  local lines = {} ---@type string[][][]

  local keymap_indexes = keymaps.keymap_location_in_path(self.path, self.keymap, {missing_behavior = "nearby"})
  local path_line = keymaps.highlight_path_virtual_text(self.path, self.keymap, keymap_indexes)

  table.insert(lines, path_line)

  vim.api.nvim_buf_set_extmark(self.buf, self.ns, 0, 0, {
    virt_lines = lines,
    virt_lines_above = false,
    virt_lines_leftcol = false,
  })
end

function Keymapper:draw_footer()
  vim.api.nvim_buf_clear_namespace(self.footer_buf, self.footer_ns, 0, -1)

  local lines = {} ---@type string[][][]

  local error_line = nil ---@type string[][] | nil
  local next_win_height ---@type integer
  local next_footer_win_height ---@type integer
  if self.validation ~= nil then
    local hl ---@type string
    if self.validation.code == "keymap_conflict" or self.validation.code == "keymap_will_be_deleted" then
      hl = "WarningMsg"
    else
      hl = "ErrorMsg"
    end
    error_line = {
      {self.validation.message, hl},
    }
    next_win_height = self.default_win_height + 1
    next_footer_win_height = self.default_footer_win_height + 1
  else
    next_win_height = self.default_win_height
    next_footer_win_height = self.default_footer_win_height
  end
  if vim.api.nvim_win_get_height(self.win) ~= next_win_height then
    vim.api.nvim_win_set_height(self.win, next_win_height)
    vim.api.nvim_win_set_height(self.footer_win, next_footer_win_height)
  end
  if error_line ~= nil then
    table.insert(lines, error_line)
  end

  local help_line = {{"  "}} ---@type string[][]
  if self:_can_confirm() then
    table.insert(help_line, {"󰌑 ", "hopper.ActionText"})
    table.insert(help_line, {" Confirm"})
  else
    table.insert(help_line, {"󰌑  Confirm", "hopper.DisabledText"})
  end
  table.insert(help_line, {"  "})
  if self.suggested_keymap ~= nil then
    table.insert(help_line, {"󰌒 ", "String"})
    table.insert(help_line, {" Accept suggestion"})
  else
    table.insert(help_line, {"󰌒  Accept suggestion", "hopper.DisabledText"})
  end
  if self.on_back ~= nil then
    table.insert(help_line, {"  "})
    local curr_mode = vim.api.nvim_get_mode().mode
    if curr_mode == "n" then
      table.insert(help_line, {"󰁮 ", "Warning"})
      table.insert(help_line, {" Back"})
    else
      table.insert(help_line, {"󰁮  Back", "hopper.DisabledText"})
    end
  end
  table.insert(lines, help_line)

  vim.api.nvim_buf_set_extmark(self.footer_buf, self.footer_ns, 0, 0, {
    virt_lines = lines,
    virt_lines_above = false,
    virt_lines_leftcol = false,
  })
end

function Keymapper:confirm()
  if not self:_can_confirm() then
    return
  end
  local datastore = require("hopper.db").datastore()
  if self.existing_file ~= nil and string.len(self.keymap) == 0 then
    -- User has cleared out an existing keymap and confirmed. Consider this a delete call.
    datastore:remove_file_keymap(self.project.name, self.path)
  else
    datastore:set_file_keymap(self.project.name, self.path, self.keymap)
  end
  vim.schedule(function()
    if self.on_keymap_set ~= nil then
      self.on_keymap_set(self)
    else
      self:close()
    end
  end)
end

function Keymapper:_suggest_keymap()
  local value = vim.api.nvim_buf_get_lines(self.buf, 0, 1, false)[1] or ""
  if string.len(value) > 0 then
    return
  end
  local datastore = require("hopper.db").datastore()
  local assigned_keymaps = utils.set(datastore:list_keymaps(self.project.name))
  local allowed_keys = utils.set(require("hopper.options").options().keymapping.keyset)
  local suggested_keymap = keymaps.keymap_for_path(self.path, 4, self.keymap_length, allowed_keys, assigned_keymaps)
  self.suggested_keymap = suggested_keymap
  self:draw()
end

function Keymapper:validate()
  if self.existing_file ~= nil and self.existing_file.path ~= self.path then
    self.validation = {
      code = "keymap_conflict",
      message = string.format("Keymap \"%s\" is already in use for file \"%s\". Overwrite?", self.keymap, self.existing_file.path),
    }
    return
  end
  if self.existing_file ~= nil and string.len(self.keymap) == 0 then
    self.validation = {
      code = "keymap_will_be_deleted",
      message = "Remove this keymap?",
    }
    return
  end

  self.validation = nil
end

function Keymapper:accept_suggestion()
  if self.suggested_keymap == nil then
    return
  end
  vim.api.nvim_buf_set_lines(self.buf, 0, 1, false, {self.suggested_keymap})
  if vim.api.nvim_get_mode().mode ~= "n" then
    -- Set the cursor position to after the new keymap. It looks more natural.
    vim.api.nvim_win_set_cursor(0, {1, string.len(self.suggested_keymap)})
  end
  self:clear_suggestion()
end

function Keymapper:clear_suggestion()
  vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1)
  self.suggested_keymap = nil
  self:draw()
end

function Keymapper:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  if vim.api.nvim_win_is_valid(self.footer_win) then
    vim.api.nvim_win_close(self.footer_win, true)
  end
  Keymapper._reset(self)
end

function Keymapper:_attach_event_handlers()
  local buf = self.buf

  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "TextChangedP"}, {
    buffer = buf,
    callback = function()
      -- Clear the `modified` flag for prompt so we can close without saving.
      vim.bo[buf].modified = false
      local value = utils.clamp_buffer_value_chars(buf, self.keymap_length)
      self.keymap = value
      if string.len(value) > 0 then
        self:clear_suggestion()
      end
      self:draw()

      if self:_can_confirm() then
        vim.schedule(function()
          self:validate()
          self:draw()
        end)
      end
    end,
  })

  vim.api.nvim_create_autocmd("ModeChanged", {
    buffer = buf,
    callback = function()
      self:draw_footer()
    end,
  })

  -- Confirm new keymap.
  local confirm_keymaps = self.actions.confirm
  for _, keymap in ipairs(confirm_keymaps) do
    vim.keymap.set(
      {"i", "n"},
      keymap,
      function()
        if self:_can_confirm() then
          self:confirm()
          return ""
        end
        -- Fallback to default return behavior.
        return vim.api.nvim_replace_termcodes("<cr>", true, false, true)
      end,
      {noremap = true, silent = true, nowait = true, expr = true, buffer = buf}
    )
  end

  -- Accept suggestion keymap.
  local accept_suggestion_keymaps = self.actions.accept_suggestion
  for _, keymap in ipairs(accept_suggestion_keymaps) do
    vim.keymap.set(
      {"i", "n"},
      keymap,
      function()
        if self.suggested_keymap ~= nil then
          vim.schedule(function()
            self:accept_suggestion()
          end)
          return ""
        end
        -- Fallback to default tab behavior.
        return vim.api.nvim_replace_termcodes("<tab>", true, false, true)
      end,
      {noremap = true, silent = true, nowait = true, expr = true, buffer = buf}
    )
  end

  if self.on_back ~= nil then
    -- Go back to previous view.
    local go_back_keymaps = self.actions.go_back
    for _, keymap in ipairs(go_back_keymaps) do
      vim.keymap.set(
        "n",
        keymap,
        function()
          self.on_back(self)
        end,
        {noremap = true, silent = true, nowait = true, buffer = buf}
      )
    end
  end

  utils.attach_close_events({
    buffer = buf,
    on_close = function()
      self:close()
    end,
    keypress_events = self.actions.close,
    vim_change_events = {"WinLeave", "BufWipeout"},
  })
end

---@return boolean
function Keymapper:_can_confirm()
  if self.existing_file ~= nil and string.len(self.keymap) == 0 then
    -- User is clearing out an existing keymap. Allow it to be deleted.
    return true
  end
  if string.len(self.keymap) < self.keymap_length then
    -- Keymap must have exactly specified number of characters.
    return false
  end
  return true
end

Keymapper._instance = nil ---@type hopper.Keymapper | nil

---@return hopper.Keymapper
function Keymapper.instance()
  if Keymapper._instance == nil then
    Keymapper._instance = Keymapper._new()
  end
  return Keymapper._instance
end

return M
