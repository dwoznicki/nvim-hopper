local keymapper_view = require("hopper.view.keymapper")

local M = {}

---@class hopper.FileKeymapsPickerOptions
---@field project_filter string | nil
---@field keymap_length_filter integer | nil

---@param opts? hopper.FileKeymapsPickerOptions
function M.open_file_keymaps_picker(opts)
  local snacks_available, snacks = pcall(require, "snacks")
  if snacks_available and snacks.picker.enabled ~= false then
    M.snacks_open_file_keymaps_picker(opts)
    return
  end
  local telescope_available, _ = pcall(require, "telescope")
  if telescope_available then
    M.telescope_open_file_keymaps_picker(opts)
    return
  end
  local mini_pick_available, _ = pcall(require, "mini.pick")
  if mini_pick_available then
    M.mini_pick_open_file_keymaps_picker(opts)
    return
  end
end

---@param opts? hopper.FileKeymapsPickerOptions
function M.snacks_open_file_keymaps_picker(opts)
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
          keymap = file.keymap,
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
        picker:find() -- Reset picker.
      end,
      edit_keymap = function(picker, item)
        if not item then
          return
        end
        keymapper_view.Keymapper:open(item.path)
        picker:close()
      end,
    },
    win = {
      input = {
        keys = {
          ["dd"] = {"delete_file_keymap", mode = "n", desc = "Delete file keymap"},
          ["m"] = {"edit_keymap", mode = "n", desc = "Edit keymap"},
        },
      },
    },
  })
end

---@param opts? hopper.FileKeymapsPickerOptions
function M.telescope_open_file_keymaps_picker(opts)
  opts = opts or {}
  local datastore = require("hopper.db").datastore()
  local files = datastore:list_file_keymaps(opts.project_filter, opts.keymap_length_filter)

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local actions_state = require("telescope.actions.state")
  local config = require("telescope.config")

  ---@param file hopper.FileKeymap
  local function entry_maker(file)
    return {
      display = string.format("%s %s %s", file.project, file.path, file.keymap),
      ordinal = file.path .. " " .. file.keymap,
      project = file.project,
      path = file.path,
    }
  end

  pickers.new(nil, {
    prompt_title = "Hopper file keymaps",
    finder = finders.new_table({
      results = files,
      entry_maker = entry_maker,
    }),
    sorter = config.values.generic_sorter({}),
    previewer = config.values.file_previewer({}),
    initial_mode = "insert",
    attach_mappings = function(prompt_buf, map)
      local function open_keymapper()
        local entry = actions_state.get_selected_entry()
        if not entry then
          return
        end
        local path = entry.path
        if path then
          keymapper_view.Keymapper:open(path)
        end
      end
      local function delete_file_keymap()
        -- Delete selected file keymap.
        local entry = actions_state.get_selected_entry()
        if not entry then
          return
        end
        datastore:remove_file_keymap(entry.project, entry.path)
        -- Clear keymap out of local list.
        for i, f in ipairs(files) do
          if f.path == entry.path then
            table.remove(files, i)
            break
          end
        end
        -- Refresh picker using updated list.
        local picker = actions_state.get_current_picker(prompt_buf)
        local new_finder = finders.new_table({results = files, entry_maker = entry_maker})
        picker:refresh(new_finder, {reset_prompt = false})
      end
      map("n", "m", open_keymapper)
      map("n", "dd", delete_file_keymap)
      return true -- Keep default mappings.
    end,
  }):find()
end

---@param opts? hopper.FileKeymapsPickerOptions
function M.mini_pick_open_file_keymaps_picker(opts)
  opts = opts or {}
  local datastore = require("hopper.db").datastore()
  local files = datastore:list_file_keymaps(opts.project_filter, opts.keymap_length_filter)
  local items = {}
  for _, file in ipairs(files) do
    table.insert(items, {
      text = string.format("%s %s %s", file.project, file.path, file.keymap),
      file = file.path,
      project = file.project,
      path = file.path,
    })
  end

  local mini_pick = require("mini.pick")
  mini_pick.start({
    source = {
      items = items,
      name = "Hopper file keymaps",
    },
  })
end

return M
