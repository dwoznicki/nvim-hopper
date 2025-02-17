local actions = require("bufhopper.actions")
local c = require("bufhopper.config")
local state = require("bufhopper.state")
local m = require("bufhopper.mode")

local M = {}

-- Re-export some command commands.
M.open = actions.open
M.close = actions.close

---Setup Bufhopper.
---@param options? BufhopperOptions
function M.setup(options)
  local config = c.default_config()
  if options ~= nil then
    config = vim.tbl_extend("force", config, options)
  end
  state.set_config(config)
  require("bufhopper.highlight").setup()
  require("bufhopper.usercommand").setup()
  state.set_mode_manager(m.ModeManager.new())
end

return M
