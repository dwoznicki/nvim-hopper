local projects = require("hopper.projects")

local M = {}

function M.new_keymap()
  local project = projects.current_project()
  local file_path = vim.api.nvim_buf_get_name(0)
  local path = projects.path_from_project_root(project.path, file_path)
  local float = require("hopper.view.keymap").float()
  float:open(path)
end

function M.toggle_view()
  local float = require("hopper.view.main").float()
  float:open()
end

function M.toggle_info()
  local overlay = require("hopper.view.info").overlay()
  if overlay.is_open then
    overlay:close()
  else
    overlay:open()
  end
end

return M
