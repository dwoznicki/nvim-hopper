local actions = require("bufhopper.actions")
local state = require("bufhopper.state")

local M = {}

-- Re-export some command commands.
M.open = actions.open
M.close = actions.close

---Setup Bufhopper.
---@param options? BufhopperOptions
function M.setup(options)
  local config = require("bufhopper.config").default_config()
  if options ~= nil then
    config = vim.tbl_deep_extend("force", {}, config, options or {})
  end
  state.set_config(config)
  require("bufhopper.highlight").setup()
  require("bufhopper.usercommand").setup()
  require("bufhopper.mode").ModeManager.create()
  require("bufhopper.integrations").setup()
end

return M
