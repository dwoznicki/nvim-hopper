local actions = require("hopper.actions")

local M = {}

---Setup Hopper.
---@param options? hopper.Options
function M.setup(options)
  require("hopper.options").set_options(options)
  require("hopper.styling").setup()
end

M.toggle_hopper = actions.toggle_hopper
M.toggle_keymapper = actions.toggle_keymapper
M.toggle_info = actions.toggle_info
M.save_project = actions.save_project
M.delete_project = actions.delete_project
M.list_file_keymaps = actions.list_file_keymaps
M.file_keymaps_picker = actions.file_keymaps_picker
M.save_file_keymap = actions.save_file_keymap
M.delete_file_keymap = actions.delete_file_keymap

return M
