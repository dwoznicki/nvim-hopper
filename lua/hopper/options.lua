local utils = require("hopper.utils")

local M = {}

---@class hopper.Options
---@field keymapping hopper.KeymappingOptions | nil

---@class hopper.KeymappingOptions
---@field keyset string | string[] | nil
---@field length integer | nil

---@class hopper.ResolvedOptions
---@field keymapping hopper.ResolvedKeymappingOptions

---@class hopper.ResolvedKeymappingOptions
---@field keyset string[]
---@field length integer

local _default_options = { ---@type hopper.ResolvedOptions
  keymapping = {
    keyset = {
      "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
    },
    length = 2,
  },
}

local _options = nil ---@type hopper.ResolvedOptions | nil

---@return hopper.ResolvedOptions
function M.default_options()
  return utils.readonly(_default_options)
end

---@param opts hopper.Options
local function normalize_and_validate_options(opts)
  if opts.keymapping ~= nil then
    local keyset = opts.keymapping.keyset
    if keyset ~= nil then
      -- Split string keysets into array.
      if type(keyset) == "string" then
        keyset = vim.split(keyset, "")
        opts.keymapping.keyset = keyset
      end
      -- Dedupe keys, guaranteeing order.
      local deduped_keyset = {} ---@type string[]
      for _, key in ipairs(keyset) do
        if not vim.tbl_contains(deduped_keyset, key) then
          table.insert(deduped_keyset, key)
        end
      end
      keyset = deduped_keyset
      -- Ensure there is at least one key in the set.
      if #keyset < 1 then
        error(string.format("`options.keymapping.keyset` must contain at least one key. Instead got: %s", opts.keymapping.keyset))
      end
      -- Ensure all keys in the set look valid.
      local invalid_keys = {} ---@type string[]
      for _, key in ipairs(keyset) do
        -- TODO: Support other keys?
        if string.len(key) > 1 then
          table.insert(invalid_keys, key)
        end
      end
      if #invalid_keys > 0 then
        error(string.format("`options.keymapping.keyset` contains %s invalid keys. Keys must be exactly one character long. Invalid keys: %s", #invalid_keys, invalid_keys))
      end
      opts.keymapping.keyset = keyset
    end

    if opts.keymapping.length ~= nil then
      local keymapping_length = opts.keymapping.length
      if not utils.is_integer(keymapping_length) or keymapping_length < 1 or keymapping_length > 3 then
        error(string.format("`options.keymapping.length` must be a valid integer between 1 and 4. Instead got: %s", keymapping_length))
      end
    end
  end
end

---@param opts hopper.Options | nil
function M.set_options(opts)
  opts = opts or {}
  normalize_and_validate_options(opts)
  _options = vim.tbl_deep_extend("force", {}, opts, _default_options) ---@type hopper.ResolvedOptions
end

---@return hopper.ResolvedOptions
function M.options()
  if _options == nil then
    return _default_options
  end
  return _options
end

return M
