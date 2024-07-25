local M = {}

---@class NextKeyContext
---@field config BufhopperConfig
---@field reserved_action_keys table<string, true>
---@field mapped_keys table<string, integer>
---@field keyset string[]
---@field prev_key string | nil
---@field key_index integer
---@field file_name string
local NextKeyContext = {}

---@param config BufhopperConfig
---@return string[]
M.determine_keyset = function(config)
  if type(config.keyset) == "string" and M[config.keyset] ~= nil then
    return M[config.keyset]
  end
  if type(config.keyset) == "table" then
    ---@diagnostic disable-next-line: return-type-mismatch
    return config.keyset
  end
  -- Just pick a reasonable default.
  return M.ergonomic
end

---@param context NextKeyContext
---@return string | nil
M.next_key_sequential = function(context)
  local key
  for _ = 1, 100 do
    key = context.keyset[context.key_index]
    if key == nil then
      break
    end
    context.key_index = context.key_index + 1
    if context.mapped_keys[key] ~= nil or context.reserved_action_keys[key] ~= nil then
      goto continue
    else
      break
    end
    ::continue::
  end
  return key
end

---@param context NextKeyContext
---@return string | nil
M.next_key_filename = function(context)
  local key
  for i = 1, string.len(context.file_name) do
    key = string.sub(context.file_name, i, i)
    if key == nil then
      break
    end
    if context.mapped_keys[key] ~= nil or context.reserved_action_keys[key] ~= nil then
      goto continue
    end
    local found_in_keyset = false
    for _, k in ipairs(context.keyset) do
      if k == key then
        found_in_keyset = true
        break
      end
    end
    if found_in_keyset then
      break
    end
    ::continue::
  end
  return key
end

M.alpha = {
  "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
}
M.numeric = {
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
}
M.ergonomic = {
  "a", "s", "d", "f", "j", "k", "l", "q", "w", "e", "r", "t", "u", "i", "o", "p", "z", "x", "c", "v", "b", "n", "m", "g", "h", "y",
}

return M
