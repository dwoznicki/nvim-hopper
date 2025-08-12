local M = {}

---Setup Hopper.
---@param options? hopper.Options
function M.setup(options)
  require("hopper.options").set_options(options)
  require("hopper.styling").setup()
  require("hopper.usercommand").setup()
end

M.toggle_jumper = require("hopper.actions").toggle_jumper
M.toggle_keymapper = require("hopper.actions").toggle_keymapper
M.toggle_info = require("hopper.actions").toggle_info
M.create_project = require("hopper.actions").create_project
M.remove_project = require("hopper.actions").remove_project
M.create_keymap = require("hopper.actions").create_keymap
M.remove_keymap = require("hopper.actions").remove_keymap

return M
