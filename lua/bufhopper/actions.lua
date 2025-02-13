local filepath = require("bufhopper.filepath")
local keysets = require("bufhopper.keysets")
local bufhopper_config = require("bufhopper.config")

local M = {}

---@class BufferKeyMapping
---@field key string
---@field buf integer
---@field file_name string
---@field file_path string
---@field file_path_tokens string[]
---@field buf_indicators string

---@param buf integer
---@param current_buf integer
---@param alternate_buf integer
---@return string
local function get_buffer_indicators(buf, current_buf, alternate_buf)
  local buf_info = vim.fn.getbufinfo(buf)[1]
  local indicator1 = (buf == current_buf) and "%" or (buf== alternate_buf and "#" or " ")
  local indicator2 = (#buf_info.windows > 0) and "a" or "h"
  local mod_indicator = (buf_info.changed == 1) and "+" or " "
  return indicator1 .. indicator2 .. mod_indicator
end

---@param ui table<string, unknown>
---@param num_buffer_rows integer
---@return integer, integer
local function get_win_dimensions(ui, num_buffer_rows)
  local available_width = math.ceil(ui.width * 0.4)
  local available_height = ui.height - 6
  -- For buffer list height, we'll try and choose a reasonable height without going over the
  -- available remaining space.
  local buffers_height = math.max(math.min(num_buffer_rows, available_height), 10)
  return buffers_height, available_width
end

---@param win_width integer
---@return integer, integer, integer
local function get_buffers_win_column_widths(win_width)
  -- Reserve space for left-most gutter. Every column should reserve a right-side gutter space.
  local available_width = win_width - 1
  -- Reserve space for key.
  local key_col_width = 1
  available_width = available_width - key_col_width - 1

  -- Reserve space for buffer indicators characters (e.g. "a", "%", "+").
  local indicators_col_width = 3
  available_width = available_width - indicators_col_width - 1

  -- -- Reserve space for file name. We'll eat space greedily for this column.
  -- local file_name_col_width = math.min(max_file_name_length, available_width)
  -- available_width = available_width - file_name_col_width - 1

  -- Any available space can be given to file path.
  local file_path_col_width = math.max(available_width - 1, 0)
  return key_col_width, file_path_col_width, indicators_col_width
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

---@param config BufhopperConfig
---@return table<BufferKeyMapping>
local function get_buffer_keymappings(config)
  -- Prepare the buffers list.
  ---@type BufferKeyMapping[]
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
    mapped_keys = mapped_keys,
    keyset = keyset,
    prev_key = prev_key,
    key_index = 1,
    file_name = "",
  }

  local current_buf = vim.api.nvim_get_current_buf()
  local alternate_buf = vim.fn.bufnr('#')
  for _, openbuf in ipairs(vim.api.nvim_list_bufs()) do
    -- if not vim.api.nvim_buf_is_loaded(openbuf) or vim.api.nvim_get_option_value("buftype", {buf = openbuf}) ~= "" then
    if vim.api.nvim_get_option_value("buftype", {buf = openbuf}) ~= "" then
      goto continue
    end
    local project_file_path = filepath.get_path_from_project_root(vim.api.nvim_buf_get_name(openbuf))
    local project_file_path_tokens = vim.split(project_file_path, "/")
    local file_name = vim.fn.fnamemodify(project_file_path, ":t")
    local buf_indicators = get_buffer_indicators(openbuf, current_buf, alternate_buf)
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
        file_name = file_name,
        file_path = project_file_path,
        file_path_tokens = project_file_path_tokens,
        buf_indicators = buf_indicators,
      }
    )
    num_buffers = num_buffers + 1
    ::continue::
  end
  table.sort(buffer_keys, function(a, b)
    return a.buf < b.buf
  end)
  return buffer_keys
end

---@param buf integer
---@param buffer_keys table<BufferKeyMapping>
---@param win_width? integer
local function draw_buffer_lines(buf, buffer_keys, win_width)
  if win_width == nil then
    local ui = vim.api.nvim_list_uis()[1]
    _, win_width = get_win_dimensions(ui, #buffer_keys)
  end
  local key_col_width, file_path_col_width, indicators_col_width = get_buffers_win_column_widths(win_width)

  ---@class TreeNode: table<string, TreeNode>
  local reverse_path_token_tree = {}

  for _, buffer_key in ipairs(buffer_keys) do
    local curr_node = reverse_path_token_tree
    for i = #buffer_key.file_path_tokens, 1, -1 do
      local path_token = buffer_key.file_path_tokens[i]
      if curr_node[path_token] == nil then
        curr_node[path_token] = {}
      end
      curr_node = curr_node[path_token]
    end
  end

  ---@type string[]
  local buffer_lines = {}
  local hl_locs = {}

  for i, buffer_key in ipairs(buffer_keys) do
    local remaining_file_path_width = file_path_col_width
    ---@type string[]
    local display_path_tokens = {}
    local significant_path_length = 0
    local curr_node = reverse_path_token_tree
    for j = #buffer_key.file_path_tokens, 1, -1 do
      local path_token = buffer_key.file_path_tokens[j]
      local text_width = vim.fn.strdisplaywidth(path_token)
      if j ~= 1 then
        -- Account for leading dir separator.
        text_width = text_width + 1
      end
      -- NOTE: Highlights need byte offsets, not display width. Therefore, we calculate the
      -- `significant_path_length` with `string.len`.
      significant_path_length = significant_path_length + string.len(path_token)
      if j ~= 1 then
        significant_path_length = significant_path_length + 1
      end
      remaining_file_path_width = remaining_file_path_width - text_width
      if remaining_file_path_width < 0 then
        break
      end
      table.insert(display_path_tokens, 1, path_token)
      local num_shared_path_tokens = 0
      for _, _ in pairs(curr_node[path_token]) do
        num_shared_path_tokens = num_shared_path_tokens + 1
      end
      if num_shared_path_tokens < 2 then
        break
      end
      curr_node = curr_node[path_token]
    end

    for j = 1, #buffer_key.file_path_tokens - #display_path_tokens, 1 do
      local path_token = buffer_key.file_path_tokens[j]
      local text_width = vim.fn.strdisplaywidth(path_token)
      if j ~= 1 then
        -- Account for leading dir separator.
        text_width = text_width + 1
      end
      if remaining_file_path_width - text_width < 0 then
        path_token = "…"
        text_width = vim.fn.strdisplaywidth(path_token)
        if j ~= 1 then
          text_width = text_width + 1
        end
        if remaining_file_path_width - text_width < 0 then
          display_path_tokens[j - 1] = "…"
          break
        end
      end
      remaining_file_path_width = remaining_file_path_width - text_width
      if remaining_file_path_width < 0 then
        break
      end
      table.insert(display_path_tokens, j, path_token)
    end

    local display_path = table.concat(display_path_tokens, "/")
    -- NOTE: Highlights need byte offsets, not display width. Therefore, we calculate the
    -- `significant_path_length` with `string.len`.
    local non_significant_path_length = string.len(display_path) - significant_path_length

    local row = i - 1

    -- -- Key at end config
    -- local display_path_width = vim.fn.strdisplaywidth(display_path)
    -- local pad_length = math.max(file_path_col_width - display_path_width, 0)
    -- local padding = string.rep(" ", pad_length)
    -- table.insert(
    --   buffer_lines,
    --   " " .. padding .. display_path .. " " .. buffer_key.key .. " "
    -- )
    -- local col_start = pad_length + 1
    -- local col_end = col_start + non_significant_path_length + 1
    -- table.insert(hl_locs, {name = "BufhopperDirPath", row = row, col_start = col_start, col_end = col_end})
    -- col_start = col_end
    -- col_end = col_start + significant_path_length - 1
    -- table.insert(hl_locs, {name = "BufhopperFileName", row = row, col_start = col_start, col_end = col_end})
    -- col_start = col_end + 1
    -- col_end = col_start + 1
    -- table.insert(hl_locs, {name = "BufhopperKey", row = row, col_start = col_start, col_end = col_end})

    -- Key at beginning config
    table.insert(
      buffer_lines,
      " " .. buffer_key.key .. " " .. display_path .. " " .. buffer_key.buf_indicators
    )
    local col_start, col_end = 1, 2
    table.insert(hl_locs, {name = "BufhopperKey", row = row, col_start = col_start, col_end = col_end})
    col_start = col_end + 1
    col_end = col_start + non_significant_path_length + 1
    table.insert(hl_locs, {name = "BufhopperDirPath", row = row, col_start = col_start, col_end = col_end})
    col_start = col_end
    col_end = col_start + significant_path_length
    table.insert(hl_locs, {name = "BufhopperFileName", row = row, col_start = col_start, col_end = col_end})
  end

  vim.api.nvim_set_option_value("modifiable", true, {buf = buf})
  -- Clear lines from buffer.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  -- Clear highlighting from buffer.
  vim.api.nvim_buf_clear_namespace(buf, 0, 0, -1)

  -- Draw the buffer keymapping lines.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, buffer_lines)
  -- Add highlights.
  for _, hl_loc in ipairs(hl_locs) do
    vim.api.nvim_buf_add_highlight(buf, 0, hl_loc.name, hl_loc.row, hl_loc.col_start, hl_loc.col_end)
  end
  vim.api.nvim_set_option_value("modifiable", false, {buf = buf})
end


---Open the floating window.
---@param config? BufhopperConfig
function M.open(config)
  if M._buffers_win and vim.api.nvim_win_is_valid(M._buffers_win) then
    -- The float is already open.
    return
  end
  if config == nil then
    config = bufhopper_config.global_config
  else
    config = vim.tbl_extend("force", bufhopper_config.global_config, config)
  end

  -- The buffer that we were on before opening the float.
  local current_buf = vim.api.nvim_get_current_buf()

  local buffer_keys = get_buffer_keymappings(config)
  local ui = vim.api.nvim_list_uis()[1]
  local buffers_height, win_width = get_win_dimensions(ui, #buffer_keys)

  -- Open the buffers floating window.
  local buffers_buf = vim.api.nvim_create_buf(false, true)
  draw_buffer_lines(buffers_buf, buffer_keys, win_width)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buffers_buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buffers_buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buffers_buf})
  vim.api.nvim_set_option_value("filetype", "bufhopperfloat", {buf = buffers_buf})

  local buffers_win_config = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = buffers_height,
    row = math.floor((ui.height - buffers_height) * 0.5) - 1,
    col = math.floor((ui.width - win_width) * 0.5),
    title = " Buffers ",
    title_pos = "center",
    border = "rounded",
  }
  local buffers_win = vim.api.nvim_open_win(buffers_buf, true, buffers_win_config)
  vim.api.nvim_set_option_value("cursorline", true, {win = buffers_win})
  vim.api.nvim_set_option_value("winhighlight", "CursorLine:BufhopperCursorLine", {win = buffers_win})

  vim.keymap.set("n", "q", ":q<cr>", {noremap = true, silent = true, buffer = buffers_buf})
  vim.keymap.set("n", "<esc>", ":q<cr>", {noremap = true, silent = true, buffer = buffers_buf})
  for i, buffer_key in ipairs(buffer_keys) do
    if buffer_key.buf == current_buf then
      vim.api.nvim_win_set_cursor(buffers_win, {i, 0})
    end
    -- pcall(
    --   vim.keymap.del,
    --   "n",
    --   buffer_key.key,
    --   {buffer = M._buffers_buf}
    -- )
    vim.keymap.set(
      "n",
      buffer_key.key,
      function()
        vim.api.nvim_win_set_cursor(buffers_win, {i, 0})
        if M._keypress_mode == "open" then
          vim.defer_fn(
            function()
              M.close()
              vim.api.nvim_set_current_buf(buffer_key.buf)
            end,
            50
          )
          return
        end
      end,
      {noremap = true, silent = true, buffer = buffers_buf}
    )
  end
  vim.keymap.set(
    "n",
    "j",
    function()
      M._keypress_mode = "jump"
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("j", true, false, true),
        "n",
        false
      )
    end,
    {silent = true, buffer = buffers_buf}
  )
  vim.keymap.set(
    "n",
    "k",
    function()
      M._keypress_mode = "jump"
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("k", true, false, true),
        "n",
        false
      )
    end,
    {silent = true, buffer = buffers_buf}
  )
  vim.keymap.set(
    "n",
    "<cr>",
    function()
      local cursor_pos = vim.api.nvim_win_get_cursor(buffers_win)
      local buffer_idx = cursor_pos[1]
      ---@type BufferKeyMapping | nil
      local buffer_key = buffer_keys[buffer_idx]
      if buffer_key ~= nil then
        M.close()
        vim.api.nvim_set_current_buf(buffer_key.buf)
      end
    end,
    {silent = true, remap = false, buffer = buffers_buf}
  )
  vim.keymap.set(
    "n",
    "dd",
    function()
      local cursor_pos = vim.api.nvim_win_get_cursor(buffers_win)
      local buffer_idx = cursor_pos[1]
      ---@type BufferKeyMapping | nil
      local buffer_key = buffer_keys[buffer_idx]
      if buffer_key ~= nil then
        vim.api.nvim_buf_delete(buffer_key.buf, {})
        table.remove(buffer_keys, buffer_idx)
        draw_buffer_lines(buffers_buf, buffer_keys)
      end
    end,
    {silent = true, buffer = buffers_buf}
  )

  M._buffers_buf = buffers_buf
  M._buffers_win = buffers_win
  M._keypress_mode = "open"

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buffers_buf,
    callback = function()
      M._buffer_keys = nil
      M._buffers_buf = nil
      M._buffers_win = nil
    end,
  })
end

function M.close()
  if M._buffers_win and vim.api.nvim_win_is_valid(M._buffers_win) then
    vim.api.nvim_win_close(M._buffers_win, true)
  end
end

function M.delete_other_buffers()
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
