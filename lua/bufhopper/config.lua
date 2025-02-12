local M = {}

---@class BufhopperConfig
---@field keyset "alpha" | "numeric" | "ergonomic" | string[]
---@field next_key "sequential" | "filename" | fun(context: NextKeyContext): string | nil
local BufhopperConfig = {}

---@return BufhopperConfig
M.default_config = function()
  return {
    -- actions = {
    --   ["do"] = require("bufhopper.actions").delete_other_buffers,
    -- },
    keyset = "ergonomic",
    next_key = "filename",
  }
end

---@param config BufhopperConfig
M.set_global_config = function(config)
  M.global_config = config
end

return M
