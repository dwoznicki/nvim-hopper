local Keysets = require("bufhopper.keysets")
local Config = require("bufhopper.config")
local Filepath = require("bufhopper.filepath")
local Float = require("bufhopper.float")

local M = {}

---@type BufhopperBuflistState
M.state = {
  buf = nil,
  buf_keys = {},
}

---@return integer
function M.get_buf()
  if M.state.buf == nil then
    error("Bufhopper buflist buffer not found!")
  end
  return M.state.buf
end

function M.setup_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  M.state.buf = buf
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "bufhopperbuflist", {buf = buf})
  vim.keymap.set("n", "q", ":q<cr>", {noremap = true, silent = true, nowait = true, buffer = buf})
end

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

function M.populate_buf_keys()
  local config = Config.state
  -- Prepare the buffers list.
  ---@type BufferKeyMapping[]
  local buf_keys = {}
  local num_buffers = 0

  local keyset = Keysets.determine_keyset(config.keyset)
  local prev_key = nil
  ---@type function(context: BufhopperNextKeyContext): string | nil
  local next_key_fn
  if type(config.next_key) == "function" then
    --- LuaLS gets this wrong.
    ---@diagnostic disable-next-line: cast-local-type
    next_key_fn = config.next_key
  elseif config.next_key == "filename" then
    next_key_fn = Keysets.next_key_filename
  else -- "sequential"
    next_key_fn = Keysets.next_key_sequential
  end
  ---@type table<string, integer>
  local mapped_keys = {}
  -- It's okay for functions to mutate this. In fact, it's necessary for the "sequential" algorithm.
  ---@type BufhopperNextKeyContext
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
    local project_file_path = Filepath.get_path_from_project_root(vim.api.nvim_buf_get_name(openbuf))
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
      buf_keys,
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
  table.sort(buf_keys, function(a, b)
    return a.buf < b.buf
  end)
  M.state.buf_keys = buf_keys
end

---@return BufferKeyMapping | nil, integer
function M.get_buffer_under_cursor()
  local win = Float.get_win()
  local cursor_pos = vim.api.nvim_win_get_cursor(win)
  local buffer_idx = cursor_pos[1]
  ---@type BufferKeyMapping | nil
  local buf_key = M.state.buf_keys[buffer_idx]
  return buf_key, buffer_idx
end

---@param win_width integer
---@return integer, integer, integer
local function get_column_widths(win_width)
  -- Reserve space for left-most gutter. Every column should reserve a right-side gutter space.
  local available_width = win_width - 1
  -- Reserve space for key.
  local key_col_width = 1
  available_width = available_width - key_col_width - 1

  -- Reserve space for buffer indicators characters (e.g. "a", "%", "+").
  local indicators_col_width = 3
  available_width = available_width - indicators_col_width - 1

  -- Any available space can be given to file path.
  local file_path_col_width = math.max(available_width - 1, 0)
  return key_col_width, file_path_col_width, indicators_col_width
end

---@class BufhopperDrawOptions
---@field win_width? integer
---@field hide_keymapping? boolean
---@param options? BufhopperDrawOptions
function M.draw(options)
  local buf_keys = M.state.buf_keys
  local buf = M.get_buf()

  options = options or {}
  local win_width = options.win_width
  if win_width == nil then
    local ui = vim.api.nvim_list_uis()[1]
    _, win_width = Float.get_win_dimensions(ui, #buf_keys)
  end
  local _, file_path_col_width, _ = get_column_widths(win_width)

  ---@class TreeNode: table<string, TreeNode>
  local reverse_path_token_tree = {}

  for _, buf_key in ipairs(buf_keys) do
    local curr_node = reverse_path_token_tree
    for i = #buf_key.file_path_tokens, 1, -1 do
      local path_token = buf_key.file_path_tokens[i]
      if curr_node[path_token] == nil then
        curr_node[path_token] = {}
      end
      curr_node = curr_node[path_token]
    end
  end

  ---@type string[]
  local buf_lines = {}
  local hl_locs = {}

  for i, buf_key in ipairs(buf_keys) do
    local remaining_file_path_width = file_path_col_width
    ---@type string[]
    local display_path_tokens = {}
    local significant_path_length = 0
    local curr_node = reverse_path_token_tree
    for j = #buf_key.file_path_tokens, 1, -1 do
      local path_token = buf_key.file_path_tokens[j]
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

    for j = 1, #buf_key.file_path_tokens - #display_path_tokens, 1 do
      local path_token = buf_key.file_path_tokens[j]
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
          -- We've reached the hard limit on horizontal space. There's not even enough room for the
          -- ellipsis, so remove the previous path token to make room.
          table.remove(display_path_tokens, j - 1)
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

    ---@type string
    local keymapping
    if options.hide_keymapping then
      -- Maintain the space, but don't display the key.
      keymapping = " "
    else
      keymapping = buf_key.key
    end

    table.insert(
      buf_lines,
      " " .. keymapping .. " " .. display_path .. " " .. buf_key.buf_indicators
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
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, buf_lines)
  -- Add highlights.
  for _, hl_loc in ipairs(hl_locs) do
    vim.api.nvim_buf_add_highlight(buf, 0, hl_loc.name, hl_loc.row, hl_loc.col_start, hl_loc.col_end)
  end
  vim.api.nvim_set_option_value("modifiable", false, {buf = buf})
end

return M
