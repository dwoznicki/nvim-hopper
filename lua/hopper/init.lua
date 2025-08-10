local M = {}

---Setup Hopper.
---@param options? hopper.Options
function M.setup(options)
  require("hopper.options").set_options(options)
  require("hopper.styling").setup()
  require("hopper.usercommand").setup()
end

M.new_keymap = require("hopper.actions").new_keymap
M.toggle_view = require("hopper.actions").toggle_view
M.toggle_info = require("hopper.actions").toggle_info

return M
