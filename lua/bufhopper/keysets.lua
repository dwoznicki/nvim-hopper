local utils = require("bufhopper.utils")
local set = utils.set

local M = {}

---@class BufhopperNextKeyContext
---@field config BufhopperConfig
---@field keyset string[]
---@field mapped_keys table<string, integer>
---@field remaining_keys table<string, true>
---@field prev_key string | nil
---@field keyset_index integer
---@field file_name string

M.presets = {
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

M.reserved_keys = {}

---@param keyset BufhopperConfig.keyset
---@return string[]
function M.determine_keyset(keyset)
  ---@type table<string, true>
  local keys
  if type(keyset) == "string" and M.presets[keyset] ~= nil then
    keys = set(M.presets[keyset])
  elseif type(keyset) == "table" then
    keys = set(keyset)
  else
    -- Just pick a reasonable default.
    keys = set(M.presets.alphanumeric)
  end
  ---@type string[]
  local reserved_keys = set(M.reserved_keys)
  local filtered_keys = {}
  for key, _ in pairs(keys) do
    if not reserved_keys[key] then
      table.insert(filtered_keys, key)
    end
  end
  return filtered_keys
end

---@param context BufhopperNextKeyContext
---@return string | nil
function M.next_key_sequential(context)
  ---@type string | nil
  for _ = 1, 100 do
    local key_candidate = context.keyset[context.keyset_index]
    if key_candidate == nil then
      return nil
    end
    if context.remaining_keys[key_candidate] ~= nil then
      return key_candidate
    end
  end
  return nil
end

---@param context BufhopperNextKeyContext
---@return string | nil
function M.next_key_filename(context)
  for i = 1, string.len(context.file_name) do
    local key_candidate = string.sub(context.file_name, i, i)
    if key_candidate == nil then
      break
    end
    if context.remaining_keys[key_candidate] ~= nil then
      return key_candidate
    end
  end
  -- We couldn't find a key for the filename. Just pick something at random.
  for key, _ in pairs(context.remaining_keys) do
    return key
  end
  return nil
end

return M
