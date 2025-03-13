local actions = require("bufhopper.actions")
local state = require("bufhopper.state")
local conf = require("bufhopper.config")

local M = {}

-- Re-export some command commands.
M.open = actions.open
M.close = actions.close

---Setup Bufhopper.
---@param options? BufhopperOptions
function M.setup(options)
  local config = conf.default_config()
  if options ~= nil then
    local options_copy = vim.tbl_deep_extend("force", {}, options) ---@type BufhopperOptions
    conf.normalize_options(options_copy)
    config = vim.tbl_deep_extend("force", {}, config, options_copy) ---@type BufhopperConfig
  end
  state.set_config(config)
  require("bufhopper.highlight").setup()
  require("bufhopper.usercommand").setup()
  require("bufhopper.mode").ModeManager.create()
  -- require("bufhopper.integrations").setup()
end

return M
