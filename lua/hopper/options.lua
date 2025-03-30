local utils = require("hopper.utils")
local readonly = utils.readonly

local M = {}

---@class hopper.Options
---@field default_mode? hopper.Mode
---@field buffers? hopper.BufferOptions

---@class hopper.BufferOptions
---@field show_unloaded? boolean default = true
---@field show_hidden? boolean default = false

---@class hopper.OptionsFull
---@field default_mode hopper.Mode
---@field buffers hopper.BufferOptionsFull

---@class hopper.BufferOptionsFull
---@field show_unloaded boolean default = true
---@field show_hidden boolean default = false

---@type hopper.OptionsFull
M.default_options = {
  default_mode = "jump",
  buffers = {
    show_unloaded = true,
    show_hidden = false,
  },
}
M.default_options = readonly(M.default_options)

---@type hopper.OptionsFull | nil
M.options = nil

---@param opts hopper.Options | nil
function M.set_options(opts)
  M.options = vim.tbl_deep_extend("force", {}, opts, M.default_options) ---@type hopper.OptionsFull
end

---@return hopper.OptionsFull
function M.get_options()
  if M.options == nil then
    return M.default_options
  end
  return M.options
end

return M
