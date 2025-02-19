local M = {}

---@class BufhopperNextKeyContext
---@field config BufhopperConfig
---@field mapped_keys table<string, integer>
---@field keyset string[]
---@field prev_key string | nil
---@field key_index integer
---@field file_name string

---@param keyset BufhopperConfig.keyset
---@return string[]
function M.determine_keyset(keyset)
  if type(keyset) == "string" and M[keyset] ~= nil then
    return M[keyset]
  end
  if type(keyset) == "table" then
    ---@diagnostic disable-next-line: return-type-mismatch
    return keyset
  end
  -- Just pick a reasonable default.
  return M.ergonomic
end

---@param context BufhopperNextKeyContext
---@return string | nil
function M.next_key_sequential(context)
  local key
  for _ = 1, 100 do
    key = context.keyset[context.key_index]
    if key == nil then
      break
    end
    context.key_index = context.key_index + 1
    if context.mapped_keys[key] ~= nil then
      goto continue
    else
      break
    end
    ::continue::
  end
  return key
end

---@param context BufhopperNextKeyContext
---@return string | nil
function M.next_key_filename(context)
  local key
  for i = 1, string.len(context.file_name) do
    key = string.sub(context.file_name, i, i)
    if key == nil then
      break
    end
    if context.mapped_keys[key] ~= nil then
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
  "a", "b", "c", "e", "f", "h", "i", "l", "m", "n", "o", "p", "r", "s", "t", "u", "v", "w", "x", "y", "z", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
}
M.numeric = {
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
}
M.ergonomic = {
  "a", "s", "f", "l", "w", "e", "r", "t", "u", "i", "o", "p", "z", "x", "c", "v", "b", "n", "m", "h", "y", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
}

return M
