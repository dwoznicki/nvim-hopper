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

-- ================
-- = User command =
-- ================

---@class hopper.UserCommandOptions
---@field name string Command name
---@field args string The args passed to the command, if any
---@field fargs string[] The args split by unescaped whitespace (when more than one argument is allowed), if any
---@field nargs string Number of arguments `:command-nargs`
---@field bang boolean "true" if the command was executed with a ! modifier
---@field line1 number The starting line of the command range
---@field line2 number The final line of the command range
---@field range number The number of items in the command range: 0, 1, or 2
---@field count number Any count supplied
---@field reg string The optional register, if specified
---@field mods string Command modifiers, if any
---@field smods table Command modifiers in a structured format. Has the same structure as the "mods" key of `nvim_parse_cmd()`.

---@param opts hopper.UserCommandOptions
local function handle_command(opts)
  -- local subcommand, keyword_args = opts.fargs[1]
  local subcommand, kv_args = utils.parse_user_command_args(opts.fargs)
  if subcommand == "toggle_jumper" then
    M.toggle_jumper()
  elseif subcommand == "toggle_keymapper" then
    M.toggle_keymapper()
  elseif subcommand == "toggle_info" then
    M.toggle_info()
  elseif subcommand == "file_keymaps_picker" then
    M.file_keymaps_picker(kv_args)
  elseif subcommand == "jump_to_file" then
    M.jump_to_file(kv_args.keymap, kv_args)
  elseif subcommand == "save_project" then
    error("TODO")
  elseif subcommand == "delete_project" then
    error("TODO")
  elseif subcommand == "list_file_keymaps" then
    error("TODO")
  elseif subcommand == "save_file_keymap" then
    error("TODO")
  elseif subcommand == "delete_file_keymap" then
    error("TODO")
  else
    print("Unrecognized subcommand: " .. (subcommand or "nil"))
  end
end

local function complete_subcommand(_, _, _)
  return {
    "toggle_jumper",
    "toggle_keymapper",
    "toggle_info",
    "file_keymaps_picker",
    "jump_to_file",
    "save_project",
    "delete_project",
    "list_file_keymaps",
    "save_file_keymap",
    "delete_file_keymap",
  }
end

---Setup ex commands. 
M.setup = function()
  vim.api.nvim_create_user_command(
    "Hopper",
    handle_command,
    {
      nargs = 1,
      complete = complete_subcommand,
      desc = "Hopper entry command",
    }
  )
end

return M
