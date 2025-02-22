local M = {}

---@alias BufhopperConfig.keyset "alpha" | "numeric" | "alphanumeric" | string[]
---@alias BufhopperConfig.next_key "sequential" | "filename" | fun(context: BufhopperNextKeyContext): string | nil

---@class BufhopperConfig
---@field keyset BufhopperConfig.keyset
---@field next_key BufhopperConfig.next_key
---@field default_mode BufhopperMode

---@class BufhopperOptions
---@field keyset? BufhopperConfig.keyset
---@field next_key? BufhopperConfig.next_key
---@field default_mode? BufhopperMode

---@return BufhopperConfig
function M.default_config()
  return {
    keyset = "alphanumeric",
    next_key = "filename",
    default_mode = "jump",
  }
end

return M
