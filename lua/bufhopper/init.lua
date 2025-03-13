local actions = require("bufhopper.actions")
local state = require("bufhopper.state")
local config = require("bufhopper.config")

local M = {}

-- Re-export some command commands.
M.open = actions.open
M.close = actions.close

---Setup Bufhopper.
---@param options? BufhopperOptions
function M.setup(options)
  local conf = config.default_config()
  if options ~= nil then
    conf = vim.tbl_deep_extend("force", {}, conf, options) ---@type BufhopperConfig
  end
  state.set_config(conf)
  require("bufhopper.highlight").setup()
  require("bufhopper.usercommand").setup()
  require("bufhopper.mode").ModeManager.create()
  -- require("bufhopper.integrations").setup()
end

return M
