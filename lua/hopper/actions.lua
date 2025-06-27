local M = {}

function M.choose_keymap()
  local project = "x"
  local path = require("hopper.filepath").get_path_from_project_root(vim.api.nvim_buf_get_name(0))
  local keymap_float = require("hopper.view.keymap_float").float()
  keymap_float:open(project, path)
end

function M.open_file_hopper()
  local project = "x"
  local float = require("hopper.view.main").float()
  float:open(project)
end

function M.show_available_keymaps()
  local project = "x"
  local overlay = require("hopper.view.available").overlay()
  overlay:open(project)
end

return M
