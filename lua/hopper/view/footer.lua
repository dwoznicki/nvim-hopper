local options = require("hopper.options")

local M = {}

---@class hopper.HelpItem
---@field keymaps string[]
---@field label string
---@field enabled boolean |nil

---@param keymap_list string[]
---@param special_keys table<string, string>
---@return string readable_keymap
local function keymaps_display(keymap_list, special_keys)
  if #keymap_list < 1 then
    return ""
  end
  local display = ""
  for _, keymap in ipairs(keymap_list) do
    if string.len(display) > 0 then
      display = display .. ", "
    end
    for str, replacement in pairs(special_keys) do
      keymap = string.gsub(keymap, str, replacement)
    end
    display = display .. keymap
  end
  return display
end

---@param help_items hopper.HelpItem[]
---@return string[][] help_line
function M.build_help_line(help_items)
  local help_line = {{" "}} ---@type string[][]
  local special_keys = options.options().actions.display.special_keys

  for _, item in ipairs(help_items) do
    local keymap = keymaps_display(item.keymaps, special_keys)
    if string.len(keymap) > 0 then
      if #help_line > 0 then
        table.insert(help_line, {"  "})
      end
      if item.enabled == nil or item.enabled then
        table.insert(help_line, {keymap, "hopper.ActionText"})
        table.insert(help_line, {" "})
        table.insert(help_line, {item.label})
      else
        table.insert(help_line, {keymap .. " " .. item.label, "hopper.DisabledText"})
      end
    end
  end
  return help_line
end

return M
