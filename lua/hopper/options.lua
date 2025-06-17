local utils = require("hopper.utils")
local readonly = utils.readonly

local M = {}

---@class hopper.Options
---@field default_mode? hopper.Mode
---@field buffers? hopper.BufferOptions
---@field files? hopper.FileOptions

---@class hopper.BufferOptions
---@field show_unloaded? boolean default = true
---@field show_hidden? boolean default = false
---@field keyset? string | string[]

---@class hopper.FileOptions
---@field keyset? string | string[]

---@class hopper.OptionsFull
---@field default_mode hopper.Mode
---@field buffers hopper.BufferOptionsFull
---@field files hopper.FileOptionsFull

---@class hopper.BufferOptionsFull
---@field show_unloaded boolean default = true
---@field show_hidden boolean default = false
---@field keyset string[]

---@class hopper.FileOptionsFull
---@field keyset string[]

local _default_options = { ---@type hopper.OptionsFull
  default_mode = "jump",
  buffers = {
    show_unloaded = true,
    show_hidden = false,
    keyset = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"},
  },
  files = {
    keyset = {
      "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
    },
  },
}

local _options = nil ---@type hopper.OptionsFull | nil

---@return hopper.OptionsFull
function M.default_options()
  return readonly(_default_options)
end

---@param opts hopper.Options | nil
function M.set_options(opts)
  opts = opts or {}
  _options = vim.tbl_deep_extend("force", {}, opts, _default_options) ---@type hopper.OptionsFull
end

---@return hopper.OptionsFull
function M.options()
  if _options == nil then
    return _default_options
  end
  return _options
end

return M
