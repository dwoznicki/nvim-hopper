local M = {}

---@alias BufhopperConfig.keyset "alpha" | "numeric" | "ergonomic" | string[]
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
    keyset = "ergonomic",
    next_key = "filename",
    default_mode = "jump",
  }
end

return M
