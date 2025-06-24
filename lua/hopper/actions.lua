local utils = require("hopper.utils")

local M = {}

function M.choose_keymap()
  local project = "x"
  local path = require("hopper.filepath").get_path_from_project_root(vim.api.nvim_buf_get_name(0))
  local datastore = require("hopper.db").datastore()
  local existing_file = datastore:get_file_by_path(project, path)
  local existing_keymap = nil ---@type string | nil
  if existing_file ~= nil then
    existing_keymap = existing_file.keymap
  end
  local keymap_float = require("hopper.view.keymap_float").float()
  keymap_float:open(project, path, existing_keymap)
end

function M.open_file_hopper()
  local project = "x"
  local datastore = require("hopper.db").datastore()
  local files = datastore:list_files(project)
  local files_float = require("hopper.view.files_float").float()
  files_float:open(project, files)
end

function M.show_available_keymaps()
  local num_chars = 2
  local project = "x"

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("modifiable", false, {buf = buf})

  local ui = vim.api.nvim_list_uis()[1]
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "editor",
    width = ui.width,
    height = ui.height,
    row = 1,
    col = 1,
    focusable = true,
    title = " Available keymaps ",
    title_pos = "center",
    border = "none",
  }
  vim.api.nvim_open_win(buf, true, win_config)

  -- Close on "q" keypress.
  vim.keymap.set(
    "n",
    "q",
    "<cmd>close<cr>",
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )

  local ns_id = vim.api.nvim_create_namespace("hopper.AvailableKeymapsLoader")
  ---@param done integer
  ---@param total integer
  local function draw_progress(done, total)
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, 1)
    vim.api.nvim_buf_set_extmark(buf, ns_id, 0, 0, {
      virt_text = {
        {string.format("%d/%d", done, total), "Comment"},
      },
      virt_text_pos = "right_align",
    })
  end


  local loop = vim.uv or vim.loop
  loop.new_timer():start(0, 0, function()
    local datastore = require("hopper.db").datastore()
    local existing_keymaps = utils.set(datastore:list_keymaps(project))
    local allowed_keys = require("hopper.options").options().files.keyset
    local num_allowed_keys = #allowed_keys
    local total_keymap_permutions = utils.count_permutations(num_allowed_keys, num_chars)
    local num_tried = 0
    vim.schedule(function()
      draw_progress(num_tried, total_keymap_permutions)
    end)
    local available_keymaps = {} ---@type string[]
    local this_keymap_indexes = {} ---@type integer[]
    for _ = 1, num_chars do
      table.insert(this_keymap_indexes, 1)
    end
    local incr_index = #this_keymap_indexes
    while true do
      local keymap = ""
      for _, idx in ipairs(this_keymap_indexes) do
        keymap = keymap .. allowed_keys[idx]
      end
      if not existing_keymaps[keymap] then
        table.insert(available_keymaps, keymap)
      end
      num_tried = num_tried + 1
      if num_tried % 5 == 0 or num_tried >= total_keymap_permutions then
        vim.schedule(function()
          draw_progress(num_tried, total_keymap_permutions)
        end)
      end
      while true do
        this_keymap_indexes[incr_index] = this_keymap_indexes[incr_index] + 1
        if this_keymap_indexes[incr_index] > num_allowed_keys then
          this_keymap_indexes[incr_index] = 1
          incr_index = incr_index - 1
          if incr_index < 1 then
            break
          end
        else
          incr_index = #this_keymap_indexes
          break
        end
      end
      if incr_index < 1 then
        break
      end
    end
    vim.schedule(function()
      vim.api.nvim_set_option_value("modifiable", true, {buf = buf})
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, available_keymaps)
      vim.api.nvim_set_option_value("modifiable", false, {buf = buf})
    end)
  end)
end

return M
