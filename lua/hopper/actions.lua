local M = {}

function M.choose_keymap()
  local path = require("hopper.filepath").get_path_from_project_root(vim.api.nvim_buf_get_name(0))
  local float = require("hopper.view.keymap").float()
  float:open(path)
end

function M.open_file_hopper()
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
