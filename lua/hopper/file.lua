local db = require("lua.hopperr.db.sqlite")

local M = {}

---@class hopper.QuickFile
---@field path string
---@field keymap string
local QuickFile = {}
QuickFile.__index = QuickFile

---@param path string
---@param keymap string
function QuickFile.new(path, keymap)
  local qfile = setmetatable({}, QuickFile)
  qfile.path = path
  qfile.keymap = keymap
  return qfile
end

M.QuickFile = QuickFile

---@class hopper.QuickFileList
---@field project string
---@field files hopper.QuickFile[]
---@field files_by_keymap table<string, hopper.QuickFile>
---@field files_by_keymap_first_key table<string, hopper.QuickFile[]>
---@field files_by_path table<string, hopper.QuickFile>
---@field unassigned_paths string[]
local QuickFileList = {}
QuickFileList.__index = QuickFileList

---@param project string
function QuickFileList.new(project)
  local qfile_list = setmetatable({}, QuickFileList)
  qfile_list.project = project
  qfile_list.files = {}
  qfile_list.files_by_keymap = {}
  qfile_list.files_by_keymap_first_key = {}
  qfile_list.files_by_path = {}
  qfile_list.unassigned_paths = {}
  return qfile_list
end

function QuickFileList:populate()
  self:_populate_from_datastore()
  self:_populate_from_open_buffers()
end

function QuickFileList:_populate_from_datastore()
  local datastore = db.get_datastore()
  for _, item in ipairs(datastore:get_quick_files(self.project)) do
    local path, keymap = item[1], item[2]
    local qfile = QuickFile.new(path, keymap)
    table.insert(self.files, qfile)
    if self.files_by_path[path] ~= nil then
      vim.notify("Duplicate quick file found while populating from datastore. File path \"" .. path .. "\" already exists.", vim.log.levels.WARN)
    end
    self.files_by_keymap[keymap] = qfile
    if self.files_by_keymap[keymap] ~= nil then
      vim.notify("Duplicate quick file found while populating from datastore. File keymap \"" .. keymap .. "\" already exists.", vim.log.levels.WARN)
    end
    self.files_by_keymap[keymap] = qfile
    local keymap_first_key = string.sub(qfile.keymap, 1, 2)
    if self.files_by_keymap_first_key[keymap_first_key] == nil then
      self.files_by_keymap_first_key[keymap_first_key] = {}
    end
    table.insert(self.files_by_keymap_first_key[keymap_first_key], qfile)
  end
end

function QuickFileList:_populate_from_open_buffers()
  local opts = require("hopper.options").get_options()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if (vim.api.nvim_buf_is_loaded(buf) or opts.buffers.show_unloaded)
      and (vim.bo[buf].buflisted or opts.buffers.show_hidden)
    then
      local full_path = vim.api.nvim_buf_get_name(buf)
      if string.sub(full_path, 1, #self.project) == self.project then
        local path = string.sub(full_path, #self.project, #full_path)
        if self.files_by_path[path] == nil then
          table.insert(self.unassigned_paths, path)
        end
      end
    end
  end
end

return M
