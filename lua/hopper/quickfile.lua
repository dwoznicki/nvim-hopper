local M = {}

---@class hopper.QuickFile
---@field path string
---@field path_tokens string[]
---@field num_significant_path_tokens integer
---@field keymap string
local QuickFile = {}
QuickFile.__index = QuickFile
M.QuickFile = QuickFile

---@param path string
---@param keymap string
function QuickFile.new(path, keymap)
  local qfile = setmetatable({}, QuickFile)
  qfile.path = path
  qfile.path_tokens = vim.split(path, "/")
  qfile.num_significant_path_tokens = 0 -- set later
  qfile.keymap = keymap
  return qfile
end

---@class hopper.QuickFileList
---@field project string
---@field files hopper.QuickFile[]
---@field files_by_keymap table<string, hopper.QuickFile>
---@field files_by_keymap_first_key table<string, hopper.QuickFile[]>
---@field files_by_path table<string, hopper.QuickFile>
local QuickFileList = {}
QuickFileList.__index = QuickFileList
M.QuickFileList = QuickFileList

---@param project string
function QuickFileList.new(project)
  local qfile_list = setmetatable({}, QuickFileList)
  qfile_list.project = project
  qfile_list.files = {}
  qfile_list.files_by_keymap = {}
  qfile_list.files_by_keymap_first_key = {}
  qfile_list.files_by_path = {}
  return qfile_list
end

function QuickFileList:populate()
  self:_populate_from_datastore()
  -- self:_populate_from_open_buffers()
  self:_determine_significant_path_tokens()
  -- self:_assign_missing_keymaps()
end

---@param qfile hopper.QuickFile
function QuickFileList:add(qfile)
  table.insert(self.files, qfile)
  if self.files_by_path[qfile.path] ~= nil then
    vim.notify("Duplicate quick file found while populating from datastore. File path \"" .. qfile.path .. "\" already exists.", vim.log.levels.WARN)
  end
  self.files_by_path[qfile.path] = qfile
  if qfile.keymap ~= nil then
    if self.files_by_keymap[qfile.keymap] ~= nil then
      vim.notify("Duplicate quick file found while populating from datastore. File keymap \"" .. qfile.keymap .. "\" already exists.", vim.log.levels.WARN)
    end
    self.files_by_keymap[qfile.keymap] = qfile
    local keymap_first_key = string.sub(qfile.keymap, 1, 2)
    if self.files_by_keymap_first_key[keymap_first_key] == nil then
      self.files_by_keymap_first_key[keymap_first_key] = {}
    end
    table.insert(self.files_by_keymap_first_key[keymap_first_key], qfile)
  end
end

function QuickFileList:_populate_from_datastore()
  local datastore = require("hopper.db").datastore()
  for _, item in ipairs(datastore:get_quick_files(self.project)) do
    local path, keymap = item[1], item[2]
    local qfile = QuickFile.new(path, keymap)
    self:add(qfile)
  end
end

-- -- This must be called after `_populate_from_datastore`!
-- function QuickFileList:_populate_from_open_buffers()
--   local unassigned_paths = {} ---@type string[]
--   local opts = require("hopper.options").options()
--   for _, buf in ipairs(vim.api.nvim_list_bufs()) do
--     if (vim.api.nvim_buf_is_loaded(buf) or opts.buffers.show_unloaded)
--       and (vim.bo[buf].buflisted or opts.buffers.show_hidden)
--     then
--       local full_path = vim.api.nvim_buf_get_name(buf)
--       if string.sub(full_path, 1, #self.project) == self.project then
--         local path = string.sub(full_path, #self.project, #full_path)
--         if self.files_by_path[path] == nil then
--           table.insert(unassigned_paths, path)
--         end
--       end
--     end
--   end
--   for _, path in ipairs(unassigned_paths) do
--     local qfile = QuickFile.new(path, nil)
--     self:add(qfile)
--   end
-- end

function QuickFileList:_determine_significant_path_tokens()
  ---@class TreeNode: table<string, TreeNode>
  local reverse_path_token_tree = {}

  for _, qfile in ipairs(self.files) do
    local curr_node = reverse_path_token_tree
    for i = #qfile.path_tokens, 1, -1 do
      local path_token = qfile.path_tokens[i]
      if curr_node[path_token] == nil then
        curr_node[path_token] = {}
      end
      curr_node = curr_node[path_token]
    end
  end

  for _, qfile in ipairs(self.files) do
    local curr_node = reverse_path_token_tree
    for j = #qfile.path_tokens, 1, -1 do
      local path_token = qfile.path_tokens[j]
      qfile.num_significant_path_tokens = qfile.num_significant_path_tokens + 1
      local num_shared_path_tokens = 0
      for _, _ in pairs(curr_node[path_token]) do
        num_shared_path_tokens = num_shared_path_tokens + 1
      end
      if num_shared_path_tokens < 2 then
        break
      end
      curr_node = curr_node[path_token]
    end
  end
end

-- function QuickFileList:_assign_missing_keymaps()
--   x, y = QuickFileList.keymap_for_path()
-- end

---@param path_tokens string[]
---@param num_path_tokens_to_check integer
---@param allowed_keys table<string, any>
---@param assigned_keymaps table<string, any>
---@return string, [integer, integer, integer, integer]
function QuickFileList.keymap_for_path(path_tokens, num_path_tokens_to_check, allowed_keys, assigned_keymaps)
  local tried_first_keys = {} ---@type table<string, true>

  -- Try to get the first letter of the filename as the first keymap letter.
  -- We do this to try an make the keymap mnemonic.
  -- If we can't find a valid candidate, we'll try the next letter in the filename, and so on.
  for i = #path_tokens, #path_tokens - num_path_tokens_to_check, -1 do
    local path_token = path_tokens[i]

    -- if i == #path_token then
    --   -- If this path token is the filename, remove the extension. It would be kinda odd to use the
    --   -- extension to determine the second key.
    --   local filename = vim.fn.fnamemodify(path_tokens[#path_tokens - 1], ":t")
    --   local file_ext = ". " .. vim.fn.fnamemodify(filename, ":e")
    --   local filename_without_ext = string.sub(filename, 1, -(#file_ext + 1))
    --   path_token = filename_without_ext
    -- end

    local first_char = nil ---@type string | nil
    local first_char_idx = -1 ---@type integer
    local path_token_chars = vim.split(path_token, "")
    for j, char in ipairs(path_token_chars) do
      char = string.lower(char)
      if allowed_keys[char] ~= nil and tried_first_keys[char] == nil then
        first_char = char
        first_char_idx = j
        break
      end
    end
    -- Try to find a reasonable second key.
    if first_char ~= nil then
      -- First, look at the other characters in this path token, minus this exact character.
      for j, char in ipairs(path_token_chars) do
        char = string.lower(char)
        local possible_keymap = first_char .. char
        if j ~= first_char_idx
          and allowed_keys[char] ~= nil
          and assigned_keymaps[possible_keymap] == nil
        then
          -- We found an available keymap. Hooray!
          return possible_keymap, {i, first_char_idx, i, j}
        end
      end
      -- Second, look for available characters the other significant path tokens.
      for j = #path_tokens, #path_tokens - num_path_tokens_to_check, -1 do
        if j ~= i then
          local other_path_token = path_tokens[k]
          local other_path_token_chars = vim.split(other_path_token, "")
          for k, char in ipairs(other_path_token_chars) do
            char = string.lower(char)
            local possible_keymap = first_char .. char
            if allowed_keys[char] ~= nil and assigned_keymaps[possible_keymap] == nil then
              -- We found an available keymap. Hooray!
              return possible_keymap, {i, first_char_idx, j, k}
            end
          end
        end
      end
      -- Third, just start trying other available characters.
      for char, _ in pairs(allowed_keys) do
        local possible_keymap = first_char .. char
        if assigned_keymaps[possible_keymap] == nil then
          return possible_keymap, {i, first_char_idx, -1, -1}
        end
      end
      -- We failed to find a good keymap with thie first character. This probably means this
      -- character is no longer available in the first keymap slot.
      tried_first_keys[first_char] = true
    end
  end
  -- If we get here, we've iterated through all path tokens, and failed to find a keymap. It's time
  -- to start picking random junk and see what sticks.
  for first_char, _ in pairs(allowed_keys) do
    for second_char, _ in pairs(allowed_keys) do
      local possible_keymap = first_char .. second_char
      if assigned_keymaps[possible_keymap] == nil then
        return possible_keymap, {-1, -1, -1, -1}
      end
    end
  end
  -- If we get here, we've utterly failed to find a decent keymap.
  error("Failed to find a keymap for " .. vim.iter(path_tokens):join("/"))
end

return M
