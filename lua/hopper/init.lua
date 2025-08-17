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
M.save_project = require("hopper.actions").save_project
M.delete_project = require("hopper.actions").delete_project
M.save_file_keymap = require("hopper.actions").save_file_keymap
M.delete_file_keymap = require("hopper.actions").delete_file_keymap

return M
