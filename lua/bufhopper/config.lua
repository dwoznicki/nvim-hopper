local M = {}

---@alias BufhopperConfig.keyset "alpha" | "numeric" | "alphanumeric" | string[]
---@alias BufhopperConfig.next_key "sequential" | "filename" | fun(context: BufhopperNextKeyContext): string | nil

---@class BufhopperConfig
---@field keyset BufhopperConfig.keyset
---@field next_key BufhopperConfig.next_key
---@field default_mode BufhopperMode
---@field jump_mode BufhopperJumpModeConfig
---@field buffers BufhopperBuffersConfig

---@class BufhopperBuffersConfig
---@field show_unloaded boolean
---@field show_hidden boolean
---@field paginate boolean

---@class BufhopperJumpModeConfig
---@field delay integer

---@class BufhopperOptions
---@field keyset? BufhopperConfig.keyset
---@field next_key? BufhopperConfig.next_key
---@field default_mode? BufhopperMode
---@field jump_mode? BufhopperJumpModeConfig
---@field buffers? BufhopperBuffersOptions

---@class BufhopperBuffersOptions
---@field show_unloaded? boolean default = true
---@field show_hidden? boolean default = false
---@field paginate? boolean default = true

---@class BufhopperJumpModeOptions
---@field delay? integer Delay in milliseconds before opening buffer. Set to 0 for no delay. default = 50

---@return BufhopperConfig
function M.default_config()
  return {
    keyset = "alphanumeric",
    next_key = "filename",
    default_mode = "jump",
    jump_mode = {
      delay = 50,
    },
    buffers = {
      show_unloaded = true,
      show_hidden = false,
      paginate = true,
    },
  }
end

return M
