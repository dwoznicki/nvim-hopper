local projects = require("hopper.projects")

local M = {}

function M.toggle_keymap_view()
  local project = projects.current_project()
  local file_path = vim.api.nvim_buf_get_name(0)
  local path = projects.path_from_project_root(project.path, file_path)
  local float = require("hopper.view.keymap_ui").form()
  float:open(path)
end

function M.toggle_view()
  local float = require("hopper.view.main").float()
  float:open()
end

function M.toggle_info_view()
  local overlay = require("hopper.view.info").overlay()
  if overlay.is_open then
    overlay:close()
  else
    overlay:open()
  end
end

---@param name string
---@param path string
---@return hopper.Project
function M.set_project(name, path)
  local datastore = require("hopper.db").datastore()
  datastore:set_project(name, path)
  return {
    name = name,
    path = path,
  }
end

---@param name string
function M.remove_project(name)
  local datastore = require("hopper.db").datastore()
  datastore:remove_project(name)
end

---@class hopper.NewKeymapOptions
---@field project hopper.Project | string | nil

---@param path string
---@param keymap string
---@param opts? hopper.NewKeymapOptions
---@return hopper.FileMapping
function M.set_keymap(keymap, path, opts)
  opts = opts or {}
  local project ---@type hopper.Project
  if opts.project then
    project = projects.resolve_project(opts.project)
  else
    project = projects.current_project()
  end
  local datastore = require("hopper.db").datastore()
  datastore:set_file(project.name, path, keymap)
  local file = datastore:get_file_by_path(project.name, path)
  if file == nil then
    error("Unable to find file mapping.")
  end
  return file
end

return M
