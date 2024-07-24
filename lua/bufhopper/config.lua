local M = {}

---@class BufhopperConfig
---@field actions table<string, fun(): any>
local BufhopperConfig = {}

---@return BufhopperConfig
M.default_config = function()
  return {
    actions = {
      ["do"] = require("bufhopper.actions").delete_other_buffers,
    },
  }
end

---@param config BufhopperConfig
M.set_global_config = function(config)
  M.global_config = config
end

return M
