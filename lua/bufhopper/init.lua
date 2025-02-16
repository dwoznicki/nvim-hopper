local Actions = require("bufhopper.actions")
local Config = require("bufhopper.config")

local M = {}

-- Re-export some command commands.
M.open = Actions.open
M.close = Actions.close

---Setup Bufhopper.
---@param options? BufhopperOptions
M.setup = function(options)
  if options ~= nil then
    Config.state = vim.tbl_extend("force", Config.default_config(), options)
  end
  require("bufhopper.highlight").setup()
  require("bufhopper.usercommand").setup()
end

return M
