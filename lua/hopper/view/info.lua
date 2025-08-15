local utils = require("hopper.utils")
local projects = require("hopper.projects")

local M = {}

---@class hopper.InfoOverlay
---@field is_open boolean
---@field project hopper.Project | nil
---@field buf integer
---@field win integer
---@field footer_buf integer
---@field footer_win integer
---@field keymap_length integer
local InfoOverlay = {}
InfoOverlay.__index = InfoOverlay
M.InfoOverlay = InfoOverlay

InfoOverlay.footer_ns = vim.api.nvim_create_namespace("hopper.InfoOverlayFooter")

---@return hopper.InfoOverlay
function InfoOverlay._new()
  local list = {}
  setmetatable(list, InfoOverlay)
  InfoOverlay._reset(list)
  return list
end

---@param overlay hopper.InfoOverlay
function InfoOverlay._reset(overlay)
  overlay.is_open = false
  overlay.project = nil
  overlay.buf = -1
  overlay.win = -1
  overlay.footer_buf = -1
  overlay.footer_win = -1
  overlay.keymap_length = -1
end

---@class hopper.OpenInfoOverlayOptions
---@field project hopper.Project | string | nil
---@field keymap_length integer | nil

---@param opts? hopper.OpenInfoOverlayOptions
function InfoOverlay:open(opts)
  opts = opts or {}
  self.project = projects.ensure_project(opts.project)
  self.keymap_length = opts.keymap_length or require("hopper.options").options().keymapping.length

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("modifiable", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "markdown", {buf = buf})

  local ui = vim.api.nvim_list_uis()[1]
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "editor",
    width = ui.width,
    height = ui.height - 2,
    row = 0,
    col = 1,
    focusable = true,
    border = "none",
  }
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
    width = ui.width,
    height = 1,
    row = ui.height - 1,
    col = 1,
    focusable = false,
    border = "none",
  }
  local footer_win = vim.api.nvim_open_win(footer_buf, false, footer_win_config)

  vim.api.nvim_set_option_value("winhighlight", "Normal:hopper.hl.FloatFooter", {win = footer_win})

  self.buf = buf
  self.win = win
  self.footer_buf = footer_buf
  self.footer_win = footer_win
  self.is_open = true

  self:_attach_event_handlers()

  self:init()
end

function InfoOverlay:init()
  local footer_buf = self.footer_buf
  local buf = self.buf

  ---@param checked integer
  ---@param available integer
  ---@param total integer
  local function draw_progress(checked, available, total)
    vim.api.nvim_buf_clear_namespace(footer_buf, self.footer_ns, 0, 1)
    vim.api.nvim_buf_set_extmark(footer_buf, self.footer_ns, 0, 0, {
      virt_text = {
        {string.format("%d/%d checked, %d available", checked, total, available), "Normal"},
      },
    })
  end
  local schedule_draw_progress = vim.schedule_wrap(draw_progress)

  local loop = vim.uv or vim.loop
  loop.new_timer():start(0, 0, function()
    local datastore = require("hopper.db").datastore()
    local existing_keymaps = utils.set(datastore:list_keymaps(self.project.name))
    local allowed_keys = require("hopper.options").options().keymapping.keyset
    local num_allowed_keys = #allowed_keys
    local total_keymap_permutions = num_allowed_keys ^ self.keymap_length
    local num_tried = 0
    local available_keymaps = {} ---@type string[]
    local this_keymap_indexes = {} ---@type integer[]
    for _ = 1, self.keymap_length do
      table.insert(this_keymap_indexes, 1)
    end
    local incr_index = #this_keymap_indexes

    while true do
      local keymap = ""
      for _, idx in ipairs(this_keymap_indexes) do
        keymap = keymap .. allowed_keys[idx]
      end
      if not existing_keymaps[keymap] then
        table.insert(available_keymaps, keymap)
      end
      num_tried = num_tried + 1
      if num_tried % 50 == 0 or num_tried >= total_keymap_permutions then
        schedule_draw_progress(num_tried, #available_keymaps, total_keymap_permutions)
      end
      while true do
        this_keymap_indexes[incr_index] = this_keymap_indexes[incr_index] + 1
        if this_keymap_indexes[incr_index] > num_allowed_keys then
          this_keymap_indexes[incr_index] = 1
          incr_index = incr_index - 1
          if incr_index < 1 then
            break
          end
        else
          incr_index = #this_keymap_indexes
          break
        end
      end
      if incr_index < 1 then
        break
      end
    end
    vim.schedule(function()
      vim.api.nvim_set_option_value("modifiable", true, {buf = buf})
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "## Project",
        string.format("%s - %s", self.project.name, self.project.path),
        "",
        "## Available keymaps",
        unpack(available_keymaps),
      })
      vim.api.nvim_set_option_value("modifiable", false, {buf = buf})
    end)
  end)
end

function InfoOverlay:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  if vim.api.nvim_win_is_valid(self.footer_win) then
    vim.api.nvim_win_close(self.footer_win, true)
  end
  InfoOverlay._reset(self)
end

function InfoOverlay:_attach_event_handlers()
  local buf = self.buf

  utils.attach_close_events({
    buffer = buf,
    on_close = function()
      self:close()
    end,
    keypress_events = {"q"},
    vim_change_events = {"WinLeave", "BufWipeout"},
  })
end

local _overlay = nil ---@type hopper.InfoOverlay | nil

---@return hopper.InfoOverlay
function M.overlay()
  if _overlay == nil then
    _overlay = InfoOverlay._new()
  end
  return _overlay
end

return M
