local utils = require("hopper.utils")
local projects = require("hopper.projects")

local M = {}

-- =================
-- = Lua functions =
-- =================

function M.toggle_jumper()
  local float = require("hopper.view.jumper").float()
  if float.is_open then
    float:close()
  else
    float:open()
  end
end

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
  local file = datastore:get_file_keymap_by_keymap(project.name, keymap)
  if file == nil then
    vim.notify(string.format('Unable to find file for keymap "%s" in project "%s".', keymap, project), vim.log.levels.WARN)
    return
  end
  local file_path = projects.path_from_cwd(project.path, file.path)
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

---@class hopper.ListKeymapOptions
---@field project_filter string | nil
---@field keymap_length_filter integer | nil

---@param opts? hopper.ListKeymapOptions
function M.list_file_keymaps(opts)
  opts = opts or {}
  local datastore = require("hopper.db").datastore()
  return datastore:list_file_keymaps(opts.project_filter, opts.keymap_length_filter)
end

---@class hopper.FileKeymapsPickerOptions
---@field project_filter string | nil
---@field keymap_length_filter integer | nil

---@param opts? hopper.FileKeymapsPickerOptions
function M.file_keymaps_picker(opts)
  opts = opts or {}
  local snacks = require("snacks")
  snacks.picker.pick({
    source = "hopper_file_keymaps",
    finder = function()
      local items = {}
      local datastore = require("hopper.db").datastore()
      local files = datastore:list_file_keymaps(opts.project_filter, opts.keymap_length_filter)
      for _, file in ipairs(files) do
        table.insert(items, {
          text = string.format("%s %s %s", file.project, file.path, file.keymap),
          file = file.path,
          path = file.path,
          project = file.project,
        })
      end
      return items
    end,
    format = "text",
    actions = {
      delete_file_keymap = function(picker, item)
        if not item then
          return
        end
        local datastore = require("hopper.db").datastore()
        datastore:remove_file_keymap(item.project, item.path)
        -- Reset picker.
        picker:find()
      end,
    },
    win = {
      input = {
        keys = {
          ["dd"] = {"delete_file_keymap", mode = "n", desc = "Delete file keymap"},
        },
      },
    },
  })
end

---@class hopper.SaveFileKeymapOptions
---@field project hopper.Project | string | nil

---@param path string
---@param keymap string
---@param opts? hopper.SaveFileKeymapOptions
---@return hopper.FileMapping
function M.save_file_keymap(keymap, path, opts)
  opts = opts or {}
  local project = projects.ensure_project(opts.project)
  local datastore = require("hopper.db").datastore()
  datastore:set_file_keymap(project.name, path, keymap)
  local file = datastore:get_file_keymap_by_path(project.name, path)
  if file == nil then
    error("Unable to find file keymap.")
  end
  return file
end

---@class hopper.DeleteFileKeymapOptions
---@field project hopper.Project | string | nil

---@param path string
---@param opts? hopper.DeleteFileKeymapOptions
function M.delete_file_keymap(path, opts)
  opts = opts or {}
  local project = projects.ensure_project(opts.project)
  local datastore = require("hopper.db").datastore()
  datastore:remove_file_keymap(project.name, path)
end

return M
