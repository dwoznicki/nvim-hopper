local actions = require("bufhopper.actions")
local bufhopper_config = require("bufhopper.config")

local M = {}

-- Re-export some command commands.
M.open = actions.open
M.close = actions.close

---Setup Bufhopper.
---@param config BufhopperConfig
M.setup = function(config)
  if config == nil then
    config = bufhopper_config.default_config()
  else
    config = vim.tbl_extend("force", bufhopper_config.default_config(), config)
  end
  bufhopper_config.set_global_config(config)
  require("bufhopper.highlight").setup()
  require("bufhopper.usercommand").setup(config)
end

return M
