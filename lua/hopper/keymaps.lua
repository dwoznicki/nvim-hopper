local M = {}

-- function _determine_significant_path_tokens()
--   ---@class TreeNode: table<string, TreeNode>
--   local reverse_path_token_tree = {}
--
--   for _, qfile in ipairs(self.files) do
--     local curr_node = reverse_path_token_tree
--     for i = #qfile.path_tokens, 1, -1 do
--       local path_token = qfile.path_tokens[i]
--       if curr_node[path_token] == nil then
--         curr_node[path_token] = {}
--       end
--       curr_node = curr_node[path_token]
--     end
--   end
--
--   for _, qfile in ipairs(self.files) do
--     local curr_node = reverse_path_token_tree
--     for j = #qfile.path_tokens, 1, -1 do
--       local path_token = qfile.path_tokens[j]
--       qfile.num_significant_path_tokens = qfile.num_significant_path_tokens + 1
--       local num_shared_path_tokens = 0
--       for _, _ in pairs(curr_node[path_token]) do
--         num_shared_path_tokens = num_shared_path_tokens + 1
--       end
--       if num_shared_path_tokens < 2 then
--         break
--       end
--       curr_node = curr_node[path_token]
--     end
--   end
-- end

M.keysets = {
  ---@type string[]
  alpha = {
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
  },
  ---@type string[]
  numeric = {
    "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
  },
  ---@type string[]
  alphanumeric = {
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
  },
  ---@type string[]
  ergonomic = {
    "a", "s", "d", "f", "g", "h", "j", "k", "l", "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "z", "x", "c", "v", "b", "n", "m", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", ";", ",", ".", "'", "[", "]", "/",
  },
}

---@param keymap_locations integer[][]
---@param location integer[]
---@return boolean
local function location_already_referenced(keymap_locations, location)
  for _, loc in ipairs(keymap_locations) do
    if loc[1] == location[1] and loc[2] == location[2] then
      return true
    end
  end
  return false
end


---@param tried_char_indexes integer[]
---@param chars string[]
---@param char_idx integer
---@return integer index or -1 to indicate we're out of viable options
local function get_next_char_index(tried_char_indexes, chars, char_idx)
  local next_char_idx = char_idx
  while true do
    next_char_idx = next_char_idx + 1
    if next_char_idx > #chars then
      next_char_idx = 1
    end
    if next_char_idx == char_idx then
      return -1
    end
    -- if tried_char_indexes[next_char_idx] == nil then
    if not vim.tbl_contains(tried_char_indexes, next_char_idx) then
      return next_char_idx
    end
  end
end

---@param path string | string[]
---@param num_path_tokens_to_check integer
---@param keymap_length integer
---@param allowed_keys table<string, any>
---@param assigned_keymaps table<string, any>
---@return string best_keymap
function M.keymap_for_path(path, num_path_tokens_to_check, keymap_length, allowed_keys, assigned_keymaps)
  if type(path) == "string" then
    path = vim.split(path, "/")
  end
  local tokenized_path = {} ---@type string[][]
  for _, part in ipairs(path) do
    if string.len(part) > 0 then
      table.insert(tokenized_path, vim.split(part, ""))
    end
  end

  -- Give up after we've checked some number of path tokens, based on the number specified
  -- by `num_path_tokens_to_check.
  --
  -- For example,
  -- path = "/path/to/some/random/file.txt"
  -- num_path_tokens_to_check = 2
  --
  -- "path", "to", "some", ⏐ "random", "file.txt"
  --                       ⏐
  --       unchecked       ⏐       checked
  local min_path_idx = math.max(#tokenized_path - num_path_tokens_to_check, 1)

  ---@alias hopper.TriedKey {char: string, path_idx: integer, char_idx: integer}

  local tried_keys = {} ---@type hopper.TriedKey[][]
  local closest_try = ""
  local try_key_idx = 1
  local path_idx = #tokenized_path
  local char_idx = 1

  while true do
    local char = tokenized_path[path_idx][char_idx]
    if tried_keys[try_key_idx] == nil then
      tried_keys[try_key_idx] = {}
    end
    assert(char ~= nil)
    table.insert(tried_keys[try_key_idx], {char = char, path_idx = path_idx, char_idx = char_idx})
    local keymap_try = ""
    for _, tried_key_list in ipairs(tried_keys) do
      keymap_try = keymap_try .. tried_key_list[#tried_key_list].char
    end
    local is_valid_keymap = allowed_keys[char] ~= nil and assigned_keymaps[keymap_try] == nil

    if is_valid_keymap then
      if string.len(keymap_try) >= keymap_length then
        return keymap_try
      end
      if string.len(keymap_try) > string.len(closest_try) then
        closest_try = keymap_try
      end
    end

    local next_try_key_idx = try_key_idx
    local next_path_idx = path_idx
    local next_char_idx = char_idx
    local nothing_left_to_try = false
    while true do
      local tried_char_indexes = {} ---@type integer[]
      for i, tried_key_list in ipairs(tried_keys) do
        for j, tried_key in ipairs(tried_key_list) do
          if tried_key.path_idx == next_path_idx and (i == next_try_key_idx or j == #tried_key_list) then
            table.insert(tried_char_indexes, tried_key.char_idx)
          end
        end
      end
      if #tokenized_path[next_path_idx] > #tried_char_indexes then
        local next_best_char_idx = -1
        for i, _ in ipairs(tokenized_path[next_path_idx]) do
          if not vim.tbl_contains(tried_char_indexes, i) then
            if next_best_char_idx == -1 or i > next_char_idx then
              next_best_char_idx = i
              if i > next_char_idx then
                break
              end
            end
          end
        end
        next_char_idx = next_best_char_idx
      else
        next_char_idx = -1
      end
      if next_char_idx == -1 then
        next_path_idx = next_path_idx - 1
        next_char_idx = 1
        if next_path_idx < min_path_idx then
          if #tried_keys == 0 then
            nothing_left_to_try = true
            break
          else
            table.remove(tried_keys, #tried_keys)
            if #tried_keys == 0 then
              nothing_left_to_try = true
              break
            end
            next_try_key_idx = next_try_key_idx - 1
            next_path_idx = tried_keys[next_try_key_idx][#tried_keys[next_try_key_idx]].path_idx
            next_char_idx = tried_keys[next_try_key_idx][#tried_keys[next_try_key_idx]].char_idx
          end
        else
          -- First character in previous path token exists.
          break
        end
      else
        -- Next character in this path token exists.
        break
      end
    end
    if nothing_left_to_try then
      break
    end
    if is_valid_keymap and try_key_idx == next_try_key_idx then
      next_try_key_idx = try_key_idx + 1
    end
    try_key_idx = next_try_key_idx
    path_idx = next_path_idx
    char_idx = next_char_idx
  end
  -- If we've reached this point, we failed to produce a good keymap using characters from the file
  -- path. It's time to start making random selections.
  local keymap_try = closest_try
  while true do
    local before_keymap_length = string.len(keymap_try)
    for char, _ in pairs(allowed_keys) do
      local next_try = closest_try .. char
      if assigned_keymaps[next_try] == nil then
        keymap_try = next_try
        break
      end
    end
    if string.len(keymap_try) >= keymap_length then
      return keymap_try
    end
    local after_keymap_length = string.len(keymap_try)
    if after_keymap_length == before_keymap_length then
      if after_keymap_length == 1 then
        -- We can't find any keymaps that look any good using characters from the file path.
        break
      end
      -- We've hit a dead end with this combination so far. Try popping off the last character and
      -- see if we can get anywhere.
      keymap_try = string.sub(keymap_try, 1, -2)
    end
  end
  -- We've failed to find a good key combination using file path characters. Time to see if there
  -- are any free combinations whatsoever that could work.
  local available_keymaps = M.list_available_keymaps(assigned_keymaps, allowed_keys, keymap_length)
  if #available_keymaps > 0 then
    return available_keymaps[1]
  end
  error("Unable to find keymap for path. All keymap combinations appear to be in use.")





--   local tried_key_combinations = {} ---@type table<string, true>
--   local tried_char_indexes = {} ---@type integer[]
--   local closest_combination = ""
--   local keymap = ""
--   local keymap_locations = {} ---@type integer[][]
--   -- local path_idx = #tokenized_path
--   -- local char_idx = 1
--
--   while true do
--     local chars = tokenized_path[path_idx]
--     if chars ~= nil then
--       local char = chars[char_idx]
--       if char ~= nil then
--         char = string.lower(char)
--         local location = {path_idx, char_idx}
--         if allowed_keys[char] ~= nil and not location_already_referenced(keymap_locations, location) then
--           local next_combination = keymap .. char
--           if tried_key_combinations[next_combination] == nil
--             and assigned_keymaps[next_combination] == nil
--           then
--             keymap = next_combination
--             table.insert(keymap_locations, location)
--             if string.len(next_combination) > string.len(closest_combination) then
--               -- Don't override existing closest combinations with new ones unless the new version
--               -- actually includes more characters. We assume that earlier attempts are "better"
--               -- than later attempts.
--               closest_combination = next_combination
--             end
--             if string.len(keymap) >= keymap_length then
--               -- Success!
--               return next_combination
--             end
--             tried_key_combinations[next_combination] = true
--             tried_char_indexes = {}
--           end
--         end
--         table.insert(tried_char_indexes, char_idx)
--         char_idx = get_next_char_index(tried_char_indexes, chars, char_idx)
--       else
--         -- We're out of characters to check. Move on to the prior path part.
--         path_idx = path_idx - 1
--         if path_idx < math.max(#tokenized_path - num_path_tokens_to_check, 1) then
--           -- Give up after we've checked some number of path tokens, based on the number specified
--           -- by `num_path_tokens_to_check.
--           --
--           -- For example,
--           -- path = "/path/to/some/random/file.txt"
--           -- num_path_tokens_to_check = 2
--           --
--           -- "path", "to", "some", ⏐ "random", "file.txt"
--           --                       ⏐
--           --       unchecked       ⏐       checked
--           path_idx = -1
--         end
--         tried_char_indexes = {}
--         char_idx = 1
--       end
--     else
--       -- We're out of valid path parts to check.
--       if path_idx == -1 then
--         -- We've run out of possible character combinations for this file path.
--         break
--       else
--         -- Pop off the last character we chose, and take another swing.
--         keymap = string.sub(keymap, 1, -2)
--         table.remove(keymap_locations, #keymap_locations)
--         path_idx = #tokenized_path
--         char_idx = 1
--       end
--     end
--   end
--   -- If we've reached this point, we failed to produce a good keymap using characters from the file
--   -- path. It's time to start making random selections.
--   keymap = closest_combination
--   while true do
--     local before_keymap_length = string.len(keymap)
--     for char, _ in pairs(allowed_keys) do
--       local next_combination = closest_combination .. char
--       if assigned_keymaps[next_combination] == nil then
--         keymap = next_combination
--         break
--       end
--     end
--     if string.len(keymap) >= keymap_length then
--       return keymap
--     end
--     local after_keymap_length = string.len(keymap)
--     if after_keymap_length == before_keymap_length then
--       if after_keymap_length == 1 then
--         -- We can't find any keymaps that look any good using characters from the file path.
--         break
--       end
--       -- We've hit a dead end with this combination so far. Try popping off the last character and
--       -- see if we can get anywhere.
--       keymap = string.sub(keymap, 1, -2)
--     end
--   end
--   -- We've failed to find a good key combination using file path characters. Time to see if there
--   -- are any free combinations whatsoever that could work.
--   if #available_keymaps > 0 then
--     return available_keymaps[1]
--   end
--   error("Unable to find keymap for path. All keymap combinations appear to be in use.")
-- end
--
-- ---@param existing_keymaps table<string, true>
-- ---@param allowed_keys table<string, true>
-- ---@param keymap_length integer
-- ---@return string[] available_keymaps
-- function M.list_available_keymaps(existing_keymaps, allowed_keys, keymap_length)
--   local num_allowed_keys = #allowed_keys
--   -- local total_keymap_permutions = num_allowed_keys ^ keymap_length
--   local num_tried = 0
--   local available_keymaps = {} ---@type string[]
--   local this_keymap_indexes = {} ---@type integer[]
--   for _ = 1, keymap_length do
--     table.insert(this_keymap_indexes, 1)
--   end
--   local incr_index = #this_keymap_indexes
--
--   while true do
--     local keymap = ""
--     for _, idx in ipairs(this_keymap_indexes) do
--       keymap = keymap .. allowed_keys[idx]
--     end
--     if not existing_keymaps[keymap] then
--       table.insert(available_keymaps, keymap)
--     end
--     num_tried = num_tried + 1
--     -- if num_tried % 50 == 0 or num_tried >= total_keymap_permutions then
--     --   schedule_draw_progress(num_tried, #available_keymaps, total_keymap_permutions)
--     -- end
--     while true do
--       this_keymap_indexes[incr_index] = this_keymap_indexes[incr_index] + 1
--       if this_keymap_indexes[incr_index] > num_allowed_keys then
--         this_keymap_indexes[incr_index] = 1
--         incr_index = incr_index - 1
--         if incr_index < 1 then
--           break
--         end
--       else
--         incr_index = #this_keymap_indexes
--         break
--       end
--     end
--     if incr_index < 1 then
--       break
--     end
--   end
--   return available_keymaps
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
    elseif idx == keymap_indexes[2] then
      key = string.sub(keymap, 2, 2)
      if next_key_index == 2 then
        hl_name = "hopper.hl.SecondKeyNext"
      else
        hl_name = "hopper.hl.SecondKey"
      end
    elseif idx == keymap_indexes[3] then
      key = string.sub(keymap, 3, 3)
      if next_key_index == 3 then
        hl_name = "hopper.hl.ThirdKeyNext"
      else
        hl_name = "hopper.hl.ThirdKey"
      end
    elseif idx == keymap_indexes[4] then
      key = string.sub(keymap, 4, 4)
      if next_key_index == 4 then
        hl_name = "hopper.hl.FourthKeyNext"
      else
        hl_name = "hopper.hl.FourthKey"
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
