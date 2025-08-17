local utils = require("hopper.utils")
local projects = require("hopper.projects")

local M = {}

function M.toggle_keymapper()
  local project = projects.current_project()
  local file_path = vim.api.nvim_buf_get_name(0)
  local path = projects.path_from_project_root(project.path, file_path)
  local float = require("hopper.view.keymapper").form()
  if float.is_open then
    float:close()
  else
    float:open(path)
  end
end

function M.toggle_jumper()
  local float = require("hopper.view.jumper").float()
  if float.is_open then
    float:close()
  else
    float:open()
  end
end

function M.toggle_info()
  local overlay = require("hopper.view.info").overlay()
  if overlay.is_open then
    overlay:close()
  else
    overlay:open()
  end
end

---@class hopper.JumpToFileOptions
---@field project hopper.Project | string | nil
---@field open_cmd string | nil

---@param keymap string
---@param opts? hopper.JumpToFileOptions
function M.jump_to_file(keymap, opts)
  opts = opts or {}
  local project = projects.ensure_project(opts.project)
  local datastore = require("hopper.db").datastore()
  local file = datastore:get_file_by_keymap(project.name, keymap)
  if file == nil then
    vim.notify(string.format('Unable to find file for keymap "%s" in project "%s".', keymap, project), vim.log.levels.WARN)
    return
  end
  local file_path = projects.path_from_project_root(project.path, file.path)
  utils.open_or_focus_file(file_path, {open_cmd = opts.open_cmd})
end

---@param name string
---@param path string
---@return hopper.Project
function M.save_project(name, path)
  local datastore = require("hopper.db").datastore()
  datastore:set_project(name, path)
  return {
    name = name,
    path = path,
  }
end

---@param name string
function M.delete_project(name)
  local datastore = require("hopper.db").datastore()
  datastore:remove_project(name)
end

---@class hopper.CreateKeymapOptions
---@field project hopper.Project | string | nil

---@param path string
---@param keymap string
---@param opts? hopper.CreateKeymapOptions
---@return hopper.FileMapping
function M.save_file_keymap(keymap, path, opts)
  opts = opts or {}
  local project = projects.ensure_project(opts.project)
  local datastore = require("hopper.db").datastore()
  datastore:set_file(project.name, path, keymap)
  local file = datastore:get_file_by_path(project.name, path)
  if file == nil then
    error("Unable to find file mapping.")
  end
  return file
end

---@class hopper.RemoveKeymapOptions
---@field project hopper.Project | string | nil

---@param path string
---@param opts? hopper.RemoveKeymapOptions
function M.delete_file_keymap(path, opts)
  opts = opts or {}
  local project = projects.ensure_project(opts.project)
  local datastore = require("hopper.db").datastore()
  datastore:remove_file(project.name, path)
end

return M
