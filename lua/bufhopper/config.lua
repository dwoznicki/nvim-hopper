local M = {}

---@alias BufhopperConfig.keyset "alpha" | "numeric" | "alphanumeric" | string[]
---@alias BufhopperConfig.next_key "sequential" | "filename" | fun(context: BufhopperNextKeyContext): string | nil

---@class BufhopperConfig
---@field keyset BufhopperConfig.keyset
---@field next_key BufhopperConfig.next_key
---@field default_mode BufhopperMode
---@field buffers BufhopperBuffersConfig

---@class BufhopperBuffersConfig
---@field show_unloaded boolean
---@field show_hidden boolean
---@field paginate boolean

---@class BufhopperOptions
---@field keyset? BufhopperConfig.keyset
---@field next_key? BufhopperConfig.next_key
---@field default_mode? BufhopperMode
---@field buffers? BufhopperBuffersOptions

---@class BufhopperBuffersOptions
---@field show_unloaded? boolean default = true
---@field show_hidden? boolean default = false
---@field paginate? boolean default = true

---@return BufhopperConfig
function M.default_config()
  return {
    keyset = "alphanumeric",
    next_key = "filename",
    default_mode = "jump",
    buffers = {
      show_unloaded = true,
      show_hidden = false,
      paginate = true,
    },
  }
end

return M
