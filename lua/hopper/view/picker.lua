local M = {}

---@class hopper.FileKeymapsPickerOptions
---@field project_filter string | nil
---@field keymap_length_filter integer | nil

---@param opts? hopper.FileKeymapsPickerOptions
function M.open_file_keymaps_picker(opts)
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

return M
