local keysets = require("bufhopper.keysets")
local filepath = require("bufhopper.filepath")
local utils = require("bufhopper.utils")
local state = require("bufhopper.state")

local M = {}

---@class BufhopperBufferListDrawOptions
---@field hide_keymapping? boolean

---@class BufhopperBufferList
---@field buf integer
---@field win integer
---@field buf_keys BufhopperBufferKeymapping[]
---@field attach fun(float: BufhopperFloatingWindow): BufhopperBufferList
---@field populate_key_mappings fun(self: BufhopperBufferList): nil
---@field draw fun(self: BufhopperBufferList, options?: BufhopperBufferListDrawOptions): nil
---@field cursor_to_buf fun(self: BufhopperBufferList, buf: integer): nil
---@field close fun(self: BufhopperBufferList): nil
local BufferList = {}
BufferList.__index = BufferList

function BufferList.attach(float)
  local buflist = {}
  setmetatable(buflist, BufferList)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "bufhopperbuflist", {buf = buf})
  buflist.buf = buf
  local win_height, win_width = utils.get_win_dimensions(0)
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "win",
    win = float.win,
    width = win_width,
    height = win_height - 1, -- space for status line
    row = 1,
    col = 1,
    border = "none",
    focusable = true,
  }
  local win = vim.api.nvim_open_win(buf, true, win_config)
  buflist.win = win
  vim.api.nvim_set_option_value("cursorline", true, {win = win})
  vim.api.nvim_set_option_value("winhighlight", "CursorLine:BufhopperCursorLine", {win = win})
  vim.keymap.set(
    "n",
    "q",
    "<cmd>q<cr>",
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      state.get_float():close()
    end,
  })
  state.set_buflist(buflist)
  return buflist
end

function BufferList:populate_key_mappings()
  local config = state.get_config()
  ---@type BufhopperBufferKeymapping[]
  local buf_keys = {}
  local num_buffers = 0

  local keyset = keysets.determine_keyset(config.keyset)
  local prev_key = nil
  ---@type function(context: BufhopperNextKeyContext): string | nil
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
    local project_file_path = filepath.get_path_from_project_root(vim.api.nvim_buf_get_name(openbuf))
    local project_file_path_tokens = vim.split(project_file_path, "/")
    local file_name = vim.fn.fnamemodify(project_file_path, ":t")
    local buf_indicators = M.get_buffer_indicators(openbuf, current_buf, alternate_buf)
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
  self.buf_keys = buf_keys
end

function BufferList:draw(options)
  options = options or {}
  local _, win_width = utils.get_win_dimensions(0)
  local _, file_path_col_width, _ = M.get_column_widths(win_width)

  ---@class TreeNode: table<string, TreeNode>
  local reverse_path_token_tree = {}

  for _, buf_key in ipairs(self.buf_keys) do
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
  ---@type {name: string, row: integer, col_start: integer, col_end: integer}[]
  local hl_locs = {}

  for i, buf_key in ipairs(self.buf_keys) do
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

  vim.api.nvim_set_option_value("modifiable", true, {buf = self.buf})
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, {}) -- clear lines
  vim.api.nvim_buf_clear_namespace(self.buf, 0, 0, -1) -- clear highlights
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, buf_lines) -- draw lines
  for _, hl_loc in ipairs(hl_locs) do -- add highlights
    vim.api.nvim_buf_add_highlight(self.buf, 0, hl_loc.name, hl_loc.row, hl_loc.col_start, hl_loc.col_end)
  end
  vim.api.nvim_set_option_value("modifiable", false, {buf = self.buf})
end

function BufferList:cursor_to_buf(buf)
  for i, buf_key in ipairs(self.buf_keys) do
    if buf_key.buf == buf then
      vim.api.nvim_win_set_cursor(self.win, {i, 0})
      break
    end
  end
end

function BufferList:close()
  vim.api.nvim_win_close(self.win, true)
end

M.BufferList = BufferList

---@param buf integer
---@param current_buf integer
---@param alternate_buf integer
---@return string
function M.get_buffer_indicators(buf, current_buf, alternate_buf)
  local buf_info = vim.fn.getbufinfo(buf)[1]
  local indicator1 = (buf == current_buf) and "%" or (buf== alternate_buf and "#" or " ")
  local indicator2 = (#buf_info.windows > 0) and "a" or "h"
  local mod_indicator = (buf_info.changed == 1) and "+" or " "
  return indicator1 .. indicator2 .. mod_indicator
end

---@param win_width integer
---@return integer, integer, integer
function M.get_column_widths(win_width)
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

return M
