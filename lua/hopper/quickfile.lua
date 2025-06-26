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

-- function QuickFileList:populate()
--   self:_populate_from_datastore()
--   -- self:_populate_from_open_buffers()
--   self:_determine_significant_path_tokens()
--   -- self:_assign_missing_keymaps()
-- end

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

-- function QuickFileList:_populate_from_datastore()
--   local datastore = require("hopper.db").datastore()
--   for _, item in ipairs(datastore:get_quick_files(self.project)) do
--     local path, keymap = item[1], item[2]
--     local qfile = QuickFile.new(path, keymap)
--     self:add(qfile)
--   end
-- end

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

---@param path string | string[]
---@param num_path_tokens_to_check integer
---@param allowed_keys table<string, any>
---@param assigned_keymaps table<string, any>
---@return string
function M.keymap_for_path(path, num_path_tokens_to_check, allowed_keys, assigned_keymaps)
  local path_tokens ---@type string[]
  if type(path) == "table" then
    path_tokens = path
  else
    path_tokens = vim.split(path, "/")
  end

  local tried_first_keys = {} ---@type table<string, true>

  -- Try to get the first letter of the filename as the first keymap letter.
  -- We do this to try an make the keymap mnemonic.
  -- If we can't find a valid candidate, we'll try the next letter in the filename, and so on.
  for i = #path_tokens, math.max(#path_tokens - num_path_tokens_to_check, 1), -1 do
    local path_token = path_tokens[i]

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
          -- return possible_keymap, {i, first_char_idx, i, j}
          return possible_keymap
        end
      end
      -- Second, look for available characters the other significant path tokens.
      for j = #path_tokens, math.max(#path_tokens - num_path_tokens_to_check, 1), -1 do
        if j ~= i then
          local other_path_token = path_tokens[j]
          local other_path_token_chars = vim.split(other_path_token, "")
          for _, char in ipairs(other_path_token_chars) do
            char = string.lower(char)
            local possible_keymap = first_char .. char
            if allowed_keys[char] ~= nil and assigned_keymaps[possible_keymap] == nil then
              -- We found an available keymap. Hooray!
              -- return possible_keymap, {i, first_char_idx, j, k}
              return possible_keymap
            end
          end
        end
      end
      -- Third, just start trying other available characters.
      for char, _ in pairs(allowed_keys) do
        local possible_keymap = first_char .. char
        if assigned_keymaps[possible_keymap] == nil then
          -- return possible_keymap, {i, first_char_idx, -1, -1}
          return possible_keymap
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
        -- return possible_keymap, {-1, -1, -1, -1}
        return possible_keymap
      end
    end
  end
  -- If we get here, we've utterly failed to find a decent keymap.
  error("Failed to find a keymap for " .. vim.iter(path_tokens):join("/"))
end

---@param path string
---@param available_width integer
---@return string truncated_path
function M.truncate_path(path, available_width)
  local path_tokens = vim.split(path, "/")
  local truncated_path_tokens = {} ---@type string[]

  local has_leading_slash = false
  if path_tokens[1] == "" then
    -- Path started with a slash. Remove this empty token early since it makes future checks more
    -- cumbersome.
    table.remove(path_tokens, 1)
    has_leading_slash = true
  end

  ---@return string
  local function join_truncated_path_tokens()
    local truncated_path = table.concat(truncated_path_tokens, "/")
    if has_leading_slash and string.sub(truncated_path, 1, 1) ~= "/" then
      truncated_path = "/" .. truncated_path
    end
    return truncated_path
  end

  local filename = table.remove(path_tokens) ---@type string
  table.insert(truncated_path_tokens, filename)
  if #path_tokens < 1 then
    return join_truncated_path_tokens()
  end
  local text_width = vim.fn.strdisplaywidth(filename) + 1
  available_width = available_width - text_width
  if available_width < 1 then
    return join_truncated_path_tokens()
  end

  local basedir = table.remove(path_tokens, 1) ---@type string
  text_width = vim.fn.strdisplaywidth(basedir)
  local next_available_width = available_width - text_width
  if next_available_width < 1 then
    basedir = "…"
    text_width = vim.fn.strdisplaywidth(basedir)
    next_available_width = available_width - text_width
    if next_available_width < 1 then
      return join_truncated_path_tokens()
    end
  end
  table.insert(truncated_path_tokens, 1, basedir)

  for i = #path_tokens, 1, -1 do
    local path_token = path_tokens[i]
    text_width = vim.fn.strdisplaywidth(path_token) + 1 -- +1 to acocunt for leading dir separator.
    next_available_width = available_width - text_width
    if next_available_width < 0 then
      path_token = "…"
      text_width = vim.fn.strdisplaywidth(path_token)
      next_available_width = available_width - text_width
      if next_available_width < 0 then
        -- We've reached the hard limit on horizontal space. There's not even enough room for the
        -- ellipsis, so remove the previous path token to make room.
        truncated_path_tokens[i - 1] = path_token
        break
      end
      table.insert(truncated_path_tokens, 2, path_token)
      break
    end
    table.insert(truncated_path_tokens, 2, path_token)
    available_width = next_available_width
  end
  return join_truncated_path_tokens()
end

---@class hopper.KeymapLocationInPathOptions
---@field missing_behavior "-1" | "end" | "nearby"

---@param path string | string[]
---@param keymap string
---@param opts? hopper.KeymapLocationInPathOptions
---@return integer[]
function M.keymap_location_in_path(path, keymap, opts)
  local path_tokens ---@type string[]
  if type(path) == "table" then
    path_tokens = path
  else
    path_tokens = vim.split(path, "/")
  end

  opts = opts or {}
  local missing_behavior = opts.missing_behavior or "-1"

  -- Returned indexes are relative to the full path string, not individual path tokens. This mapping
  -- allows us to determine full path index while checking each path token one by one.
  local path_token_offsets = {} ---@type table<integer, integer>
  local last_index = 0
  for i, path_token in ipairs(path_tokens) do
    path_token_offsets[i] = last_index
    -- NOTE: Highlights need byte offsets, not display width. Therefore, we calculate the
    -- `significant_path_length` with `string.len`.
    last_index = last_index + string.len(path_token) + 1 -- +1 to account for leading dir separator.
  end

  local path_indexes = {} ---@type integer[] 
  local keymap_tokens = vim.split(keymap, "")
  -- Iterate through keys in the given keymap, trying to find an index in the path that matches the
  -- given key. We'll draw a visual indicator at this index.
  for _, key in ipairs(keymap_tokens) do
    local location_found = false
    for i = #path_tokens, 1, -1 do
      local path_token = path_tokens[i]
      local offset = path_token_offsets[i]
      -- Iterate path token characters, checking for a match with the current key.
      local token_chars = vim.split(path_token, "")
      for j, char in ipairs(token_chars) do
        local path_index = offset + j
        if key == char and not vim.tbl_contains(path_indexes, path_index) then
          table.insert(path_indexes, path_index)
          location_found = true
          break
        end
      end
      if location_found then
        break
      end
    end
    if not location_found then
      local key_index ---@type integer
      if missing_behavior == "end" then
        -- First blank index after file path. Increment last index so that next missing location
        -- is after this one.
        key_index = last_index
        last_index = last_index + 1
      elseif missing_behavior == "nearby" then
        -- Next index after previous found key index. If there is no previous key index, slap key at
        -- the end of the path, just like "end" behavior.
        if path_indexes[1] ~= nil then
          key_index = path_indexes[1] + 1
        else
          key_index = last_index
        end
      else
        -- Dummy index. This cannot be used, meaning it's up to the caller to determine what to do
        -- in this case.
        key_index = -1
      end
      table.insert(path_indexes, key_index)
    end
  end
  return path_indexes
end

---@class hopper.HighlightPathOptions
---@field next_key_index integer

---@param path string
---@param keymap string
---@param keymap_indexes integer[]
---@param opts? hopper.HighlightPathOptions
---@return string[][]
function M.highlight_path_virtual_text(path, keymap, keymap_indexes, opts)
  opts = opts or {}
  local next_key_index = opts.next_key_index or -1

  local highlighted_parts = {} ---@type string[][]
  local start_idx = 1
  local sorted_indexes = require("hopper.utils").sorted(keymap_indexes)
  for _, idx in ipairs(sorted_indexes) do
    local part = string.sub(path, start_idx, idx - 1)
    local key ---@type string
    local hl_name ---@type string
    if idx == keymap_indexes[1] then
      key = string.sub(keymap, 1, 1)
      if next_key_index == 1 then
        hl_name = "hopper.hl.FirstKeyNext"
      else
        hl_name = "hopper.hl.FirstKey"
      end
    else
      key = string.sub(keymap, 2, 2)
      if next_key_index == 2 then
        hl_name = "hopper.hl.SecondKeyNext"
      else
        hl_name = "hopper.hl.SecondKey"
      end
    end
    table.insert(highlighted_parts, {part, "hopper.hl.SecondaryText"})
    table.insert(highlighted_parts, {key, hl_name})
    start_idx = idx + 1
  end
  local part = string.sub(path, start_idx)
  table.insert(highlighted_parts, {part, "hopper.hl.SecondaryText"})
  return highlighted_parts
end

return M
