-- local actions = require("hopper.actions")
-- local state = require("hopper.state")
-- local config = require("hopper.config")

local M = {}

-- Re-export some command commands.
-- M.open = actions.open
-- M.close = actions.close

---Setup Hopper.
---@param options? hopper.Options
function M.setup(options)
  require("hopper.options").set_options(options)
  -- local conf = config.default_config()
  -- if options ~= nil then
  --   conf = vim.tbl_deep_extend("force", {}, conf, options) ---@type BufhopperConfig
  -- end
  -- state.set_config(conf)
  -- require("lua.hopperr.highlight").setup()
  -- require("lua.hopperr.usercommand").setup()
  -- require("lua.hopperr.mode").ModeManager.create()
  -- -- require("bufhopper.integrations").setup()
end

M.choose_keymap = require("hopper.actions").choose_keymap

return M
