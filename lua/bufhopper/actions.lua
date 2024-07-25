local filepath = require("bufhopper.filepath")
local keysets = require("bufhopper.keysets")
local bufhopper_config = require("bufhopper.config")

local M = {}

---@param buf integer
---@return string
local function get_buffer_indicators(buf)
  local buf_info = vim.fn.getbufinfo(buf)[1]
  local indicators = ""
  if buf_info.loaded == 1 then
    indicators = indicators .. "a"
  elseif buf_info.hidden == 1 then
    indicators = indicators .. "h"
  end
  if buf_info.changed == 1 then
    indicators = indicators .. "+"
  end
  return indicators
end

---@param ui table<string, unknown>
---@param num_buffer_rows integer
---@param num_action_rows integer
---@return integer, integer, integer
local function get_windows_dimensions(ui, num_buffer_rows, num_action_rows)
  local available_width = math.ceil(ui.width * 0.4)
  local available_height = ui.height - 6
  -- First, see how many lines we need to reserve for actions.
  -- If there are no actions, we won't show the floating window.
  local actions_height = num_action_rows
  available_height = available_height - actions_height
  -- For buffer list height, we'll try and choose a reasonable height without going over the
  -- available remaining space.
  local buffers_height = math.max(math.min(num_buffer_rows, available_height), 10)
  return buffers_height, actions_height, available_width
end

---@param win_width integer
---@param max_file_name_length integer
---@param max_dir_path_length integer
---@return integer, integer, integer
local function get_buffers_column_widths(win_width, max_file_name_length, max_dir_path_length)
  -- Reserve space for left-most gutter. Every column should reserve a right-side gutter space.
  local available_width = win_width - 1
  -- Reserve space for key.
  local key_col_width = 1
  available_width = available_width - key_col_width - 1

  -- NOTE: Removing for now. Don't like how it looks. 
  -- Reserve space for buffer indicators characters (e.g. "a", "%", "+").
  -- local indicators_col_width = 2
  -- available_width = available_width - indicators_col_width - 1

  -- Reserve space for file name. We'll eat space greedily for this column.
  local file_name_col_width = math.min(max_file_name_length, available_width)
  available_width = available_width - file_name_col_width - 1
  -- Any available space can be given to dir path.
  local dir_path_col_width = math.max(available_width - 1, 0)
  return key_col_width, file_name_col_width, dir_path_col_width
end

---@param keymap string
---@return string
local function get_first_key(keymap)
  local special_key_pattern = "^<%a+>"
  local first_key = keymap:match(special_key_pattern)
  if first_key then
    return first_key
  end
  return keymap:sub(1, 1)
end

---Open the floating window.
---@param config? BufhopperConfig
M.open = function(config)
  if config == nil then
    config = bufhopper_config.global_config
  else
    config = vim.tbl_extend("force", bufhopper_config.global_config, config)
  end

  local ui = vim.api.nvim_list_uis()[1]
  -- Prepare the actions list.
  local num_actions = 0
  ---@type table<string, true>
  local reserved_action_keys = {}
  for keymap, _ in pairs(config.actions) do
    local first_key = get_first_key(keymap)
    reserved_action_keys[first_key] = true
    num_actions = num_actions + 1
  end

  -- Prepare the buffers list.
  ---@type {key: string, buf: integer, file_path: string, file_name: string, dir_path: string, project_dir_path: string, buf_indicators: string}[]
  local buffer_keys = {}
  local num_buffers = 0

  local keyset = keysets.determine_keyset(config)
  local prev_key = nil
  ---@type fun(context: NextKeyContext): string | nil
  local next_key_fn
  if type(config.next_key) == "function" then
    --- LuaLS gets this wrong.
    ---@diagnostic disable-next-line: cast-local-type
    next_key_fn = config.next_key
  elseif config.next_key == "filename" then
    next_key_fn = keysets.next_key_filename
  else -- "sequential"
    next_key_fn = keysets.next_key_sequential
  end
  ---@type table<string, integer>
  local mapped_keys = {}
  -- It's okay for functions to mutate this. In fact, it's necessary for the "sequential" algorithm.
  ---@type NextKeyContext
  local next_key_context = {
    config = config,
    reserved_action_keys = reserved_action_keys,
    mapped_keys = mapped_keys,
    keyset = keyset,
    prev_key = prev_key,
    key_index = 1,
    file_name = "",
  }

  local file_name_counts = {}
  local max_file_name_length = 0
  local max_dir_path_length = 0

  for _, openbuf in ipairs(vim.api.nvim_list_bufs()) do
    if not vim.api.nvim_buf_is_loaded(openbuf) or vim.api.nvim_get_option_value("buftype", {buf = openbuf}) ~= "" then
      goto continue
    end
    local file_path = vim.api.nvim_buf_get_name(openbuf)
    local file_name = vim.fn.fnamemodify(file_path, ":t")
    if file_name_counts[file_name] == nil then
      file_name_counts[file_name] = 1
    else
      file_name_counts[file_name] = file_name_counts[file_name] + 1
    end
    if #file_name > max_file_name_length then
      max_file_name_length = #file_name
    end
    local dir_path = string.sub(file_path, 1, -#file_name - 1)
    local project_dir_path = filepath.get_path_from_project_root(dir_path)
    if #project_dir_path > max_dir_path_length then
      max_dir_path_length = #project_dir_path
    end
    local buf_indicators = get_buffer_indicators(openbuf)
    next_key_context.file_name = file_name
    local key
    for _ = 1, 40 do
      key = next_key_fn(next_key_context)
      if key ~= nil then
        break
      end
    end
    if key == nil then
      break
    end
    next_key_context.prev_key = key
    mapped_keys[key] = openbuf
    table.insert(
      buffer_keys,
      {
        key = key,
        buf = openbuf,
        file_path = file_path,
        file_name = file_name,
        dir_path = dir_path,
        project_dir_path = project_dir_path,
        buf_indicators = buf_indicators,
      }
    )
    num_buffers = num_buffers + 1
    ::continue::
  end
  table.sort(buffer_keys, function(a, b)
    return a.buf < b.buf
  end)

  local buffers_height, actions_height, win_width = get_windows_dimensions(ui, num_actions, num_actions)

  -- Open the buffers floating window.
  local buffers_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buffers_buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buffers_buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buffers_buf})
  vim.api.nvim_set_option_value("filetype", "bufhopperfloat", {buf = buffers_buf})
  vim.keymap.set("n", "<esc>", ":q<cr>", {noremap = true, silent = true, buffer = buffers_buf})
  local buffer_lines = {}
  local hl_locs = {}
  local key_col_width, file_name_col_width, dir_path_col_width = get_buffers_column_widths(win_width, max_file_name_length, max_dir_path_length)
  for i, buffer_key in ipairs(buffer_keys) do
    local file_name = buffer_key.file_name
    if #file_name > file_name_col_width then
      file_name = string.sub(file_name, 1, file_name_col_width - 1) .. "…"
    end
    local dir_path = buffer_key.project_dir_path
    if file_name_counts[file_name] < 2 or dir_path_col_width == 0 then
      dir_path = ""
    elseif #dir_path > dir_path_col_width then
      dir_path = string.sub(dir_path, 1, dir_path_col_width - 1) .. "…"
    end
    table.insert(
      buffer_lines,
      string.format(
        " %-" .. key_col_width .. "s %-" .. file_name_col_width .. "s %-" .. dir_path_col_width .. "s",
        buffer_key.key,
        file_name,
        dir_path
      )
    )

    local row = i - 1
    local col_start, col_end = 1, 2
    table.insert(hl_locs, {name = "BufhopperKey", row = row, col_start = col_start, col_end = col_end})
    col_start = col_end + 1
    col_end = col_start + file_name_col_width
    table.insert(hl_locs, {name = "BufhopperFileName", row = row, col_start = col_start, col_end = col_end})
    col_start = col_end + 1
    col_end = col_start + dir_path_col_width
    table.insert(hl_locs, {name = "BufhopperDirPath", row = row, col_start = col_start, col_end = col_end})

    vim.keymap.set(
      "n",
      buffer_key.key,
      function()
        M.close()
        vim.api.nvim_set_current_buf(buffer_key.buf)
      end,
      {noremap = true, silent = true, buffer = buffers_buf}
    )
  end
  vim.api.nvim_buf_set_lines(buffers_buf, 0, -1, false, buffer_lines)
  vim.api.nvim_set_option_value("modifiable", false, {buf = buffers_buf})

  local buffers_win_config = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = buffers_height,
    row = 1,
    col = math.ceil(ui.width - win_width) - 3,
    title = "Buffers",
    border = "rounded",
  }
  local buffers_win = vim.api.nvim_open_win(buffers_buf, true, buffers_win_config)

  for _, hl_loc in ipairs(hl_locs) do
    vim.api.nvim_buf_add_highlight(buffers_buf, 0, hl_loc.name, hl_loc.row, hl_loc.col_start, hl_loc.col_end)
  end

  -- Open the actions floating window.
  local actions_buf
  local actions_win
  if num_actions > 0 then
    actions_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("buftype", "nofile", {buf = actions_buf})
    vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = actions_buf})
    vim.api.nvim_set_option_value("swapfile", false, {buf = actions_buf})
    vim.api.nvim_set_option_value("filetype", "bufhopperfloat", {buf = actions_buf})
    vim.keymap.set("n", "<esc>", ":q<cr>", {noremap = true, silent = true, buffer = actions_buf})
    local actions_win_config = {
      style = "minimal",
      relative = "editor",
      width = win_width,
      height = actions_height,
      row = buffers_height + 3,
      col = math.ceil(ui.width - win_width) - 3,
      title = "Actions",
      border = "rounded",
    }
    actions_win = vim.api.nvim_open_win(actions_buf, false, actions_win_config)
  end

  M._buffer_keys = buffer_keys
  M._buffers_buf = buffers_buf
  M._buffers_win = buffers_win
  M._actions_buf = actions_buf
  M._actions_win = actions_win

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buffers_buf,
    callback = function()
      if M._actions_win ~= nil then
        vim.api.nvim_win_close(M._actions_win, true)
      end
      M._buffer_keys = nil
      M._buffers_buf = nil
      M._buffers_win = nil
      M._actions_buf = nil
      M._actions_win = nil
    end,
  })
end

-- ---Open the overlay.
-- ---@param config BufhopperConfig
-- M._open = function(config)
--   local ui = vim.api.nvim_list_uis()[1]
--   local width = math.ceil(ui.width * 0.3)
--   local height = math.ceil(ui.height * 0.7)
--   local options = {
--     style = "minimal",
--     relative = "editor",
--     width = width,
--     height = height,
--     row = 1,
--     col = math.ceil(ui.width - width) - 3,
--     title = "Buffers",
--     border = "rounded",
--   }
--   local buf = vim.api.nvim_create_buf(false, true)
--   local win = vim.api.nvim_open_win(buf, true, options)
--   vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
--   vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
--   vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
--   vim.api.nvim_set_option_value("filetype", "bufferoverlay", {buf = buf})
--   vim.keymap.set("n", "<esc>", ":q<cr>", {noremap = true, silent = true, buffer = buf})
--
--   local buffer_keys = {}
--   local i = 1
--   for _, openbuf in ipairs(vim.api.nvim_list_bufs()) do
--     if not vim.api.nvim_buf_is_loaded(openbuf) or vim.api.nvim_get_option_value("buftype", {buf = openbuf}) ~= "" then
--       goto continue
--     end
--     local file_path = vim.api.nvim_buf_get_name(openbuf)
--     local key = keysets.ergonomic[i]
--     if key == nil then
--       break
--     end
--     i = i + 1
--     vim.keymap.set(
--       "n",
--       key,
--       function()
--         M.close()
--         vim.api.nvim_set_current_buf(openbuf)
--       end,
--       {noremap = true, silent = true, buffer = buf}
--     )
--     table.insert(buffer_keys, {key = key, buf = openbuf, file_path = file_path})
--     ::continue::
--   end
--
--   table.sort(buffer_keys, function(a, b)
--     return a.buf < b.buf
--   end)
--
--   local keymap_col_width = 1
--   local file_path_col_width = math.floor(width - keymap_col_width - 5)
--
--   local lines = {}
--   table.insert(lines, "")
--   local hl_locs = {}
--   for j, buffer_key in ipairs(buffer_keys) do
--     local file_name = vim.fn.fnamemodify(buffer_key.file_path, ":t")
--     local file_name_len = string.len(file_name)
--     local path_without_file_name = string.sub(buffer_key.file_path, 1, -file_name_len - 1)
--     local available_col_width = file_path_col_width - file_name_len
--     local dir_path
--     if available_col_width < 1 then
--       -- This is either a really long file name, or we have very little space to work with.
--       -- We'll need to truncate the file name. Unlike path truncation, we'll slice characters off
--       -- the tail instead of off the beginning.
--       file_name = string.sub(file_name, 1, available_col_width - 1) .. "…"
--       dir_path = ""
--     else
--       dir_path = filepath.get_path_from_project_root(path_without_file_name)
--       local char_overflow = string.len(dir_path) - available_col_width
--       if char_overflow > available_col_width then
--         -- We don't have room for any of the path.
--         dir_path = ""
--       elseif char_overflow > 0 then
--         dir_path = "…" .. string.sub(dir_path, char_overflow, -1)
--       end
--     end
--     local file_path = dir_path .. file_name
--     table.insert(lines, string.format(" %-" .. keymap_col_width .. "s %-" .. string.len(file_path) .. "s ", buffer_key.key, file_path))
--
--     local row = j
--     local col_start, col_end = 1, 2
--     table.insert(hl_locs, {name = "BufhopperKey", row = row, col_start = col_start, col_end = col_end})
--     col_start = col_end + 1
--     col_end = col_start + string.len(dir_path)
--     table.insert(hl_locs, {name = "BufhopperFilePath", row = row, col_start = col_start, col_end = col_end})
--     col_start = col_end
--     col_end = col_start + string.len(file_name)
--     table.insert(hl_locs, {name = "BufhopperFileName", row = row, col_start = col_start, col_end = col_end})
--   end
--
--   vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
--   vim.api.nvim_set_option_value("modifiable", false, {buf = buf})
--
--   for _, hl_loc in ipairs(hl_locs) do
--     vim.api.nvim_buf_add_highlight(buf, 0, hl_loc.name, hl_loc.row, hl_loc.col_start, hl_loc.col_end)
--   end
--
--   if config.actions and next(config.actions) ~= nil then
--     local num_actions = 0
--     for _, _ in pairs(config.actions) do
--       num_actions = num_actions + 1
--     end
--     local actions_width = width
--     local actions_height = num_actions
--     local actions_options = {
--       style = "minimal",
--       relative = "editor",
--       width = actions_width,
--       height = actions_height,
--       row = 1,
--       col = math.ceil(ui.width - actions_width) - 3,
--       title = "Actions",
--       border = "rounded",
--     }
--     local actions_buf = vim.api.nvim_create_buf(false, true)
--     local actions_win = vim.api.nvim_open_win(actions_buf, true, actions_options)
--     vim.api.nvim_set_option_value("buftype", "nofile", {buf = actions_buf})
--     vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = actions_buf})
--     vim.api.nvim_set_option_value("swapfile", false, {buf = actions_buf})
--     vim.api.nvim_set_option_value("filetype", "bufferoverlay", {buf = actions_buf})
--     vim.keymap.set("n", "<esc>", ":q<cr>", {noremap = true, silent = true, buffer = actions_buf})
--   end
--
--   M._buffer_keys = buffer_keys
--   M._overlay_buf = buf
--   M._overlay_win = win
--
--   vim.api.nvim_create_autocmd("BufWipeout", {
--     buffer = buf,
--     callback = function()
--       M._buffer_keys = nil
--       M._overlay_buf = nil
--       M._overlay_win = nil
--     end,
--   })
-- end

M.close = function()
  if M._buffers_win and vim.api.nvim_win_is_valid(M._buffers_win) then
    vim.api.nvim_win_close(M._buffers_win, true)
  end
end

M.delete_other_buffers = function()
  M.close()
  local curbuf = vim.api.nvim_get_current_buf()
  local num_closed = 0
  for _, openbuf in ipairs(vim.api.nvim_list_bufs()) do
    if not vim.api.nvim_buf_is_loaded(openbuf) or vim.api.nvim_get_option_value("buftype", {buf = openbuf}) ~= "" then
      goto continue
    end
    if openbuf == curbuf then
      goto continue
    end
    vim.api.nvim_buf_delete(openbuf, {})
    num_closed = num_closed + 1
    ::continue::
  end
  print(num_closed .. " buffers closed")
end

return M
