local utils = require("bufhopper.utils")
local state = require("bufhopper.state")

local M = {}

---@class BufhopperFloatingWindow
---@field win integer
---@field buf integer
---@field open fun(): BufhopperFloatingWindow
---@field is_open fun(self: BufhopperFloatingWindow): boolean
---@field focus fun(self: BufhopperFloatingWindow): nil
---@field close fun(self: BufhopperFloatingWindow): nil
local FloatingWindow = {}
FloatingWindow.__index = FloatingWindow

function FloatingWindow.open()
  local float = {}
  setmetatable(float, FloatingWindow)
  local buf = vim.api.nvim_create_buf(false, true)
  float.buf = buf
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  local ui = vim.api.nvim_list_uis()[1]
  local win_width, win_height = utils.get_win_dimensions()
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = 3,
    col = math.floor((ui.width - win_width) * 0.5),
    -- border = "none",
    focusable = false,
    title = " Buffers ",
    title_pos = "center",
    border = "rounded",
  }
  local win = vim.api.nvim_open_win(buf, false, win_config)
  float.win = win

  state.set_floating_window(float)
  return float
end

function FloatingWindow:is_open()
  return self.win ~= nil and vim.api.nvim_win_is_valid(self.win)
end

function FloatingWindow:focus()
  vim.api.nvim_set_current_win(state.get_buffer_table().win)
end

function FloatingWindow:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  state.get_buffer_table():close()
  state.get_status_line():close()
end

M.FloatingWindow = FloatingWindow

---@class BufhopperBufferTableDrawOptions
---@field hide_keymapping? boolean

---@class BufhopperBufferTable
---@field buf integer
---@field win integer
---@field attach fun(float: BufhopperFloatingWindow): BufhopperBufferTable
---@field draw fun(self: BufhopperBufferTable, options?: BufhopperBufferTableDrawOptions): nil
---@field cursor_to_buf fun(self: BufhopperBufferTable, buf: integer): nil
---@field cursor_to_row fun(self: BufhopperBufferTable, row: integer): nil
---@field buffer_under_cursor fun(self: BufhopperBufferTable): BufhopperBuffer | nil
local BufferTable = {}
BufferTable.__index = BufferTable

function BufferTable.attach(float)
  local buftable = {}
  setmetatable(buftable, BufferTable)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "BufhopperFloat", {buf = buf})
  buftable.buf = buf
  local win_width, win_height = utils.get_win_dimensions()
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "win",
    win = float.win,
    width = win_width,
    height = win_height - 1, -- space for status line
    row = 0,
    col = 0,
    border = "none",
    focusable = true,
  }
  local win = vim.api.nvim_open_win(buf, true, win_config)
  buftable.win = win
  vim.api.nvim_set_option_value("cursorline", true, {win = win})
  vim.api.nvim_set_option_value("winhighlight", "CursorLine:BufhopperCursorLine", {win = win})

  -- -- Close on "q" keypress.
  -- vim.keymap.set(
  --   "n",
  --   "q",
  --   "<cmd>q<cr>",
  --   {noremap = true, silent = true, nowait = true, buffer = buf}
  -- )
  -- -- Close on "<esc>" keypress.
  -- vim.keymap.set(
  --   "n",
  --   "<esc>",
  --   "<cmd>q<cr>",
  --   {noremap = true, silent = true, nowait = true, buffer = buf}
  -- )
  -- require("bufhopper.integrations").clear_whichkey(buf)

  -- Close the float when the cursor leaves.
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      state.get_floating_window():close()
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      state.get_floating_window():close()
    end,
  })
  state.set_buffer_table(buftable)
  return buftable
end


function BufferTable:draw(options)
  local buffers = state.get_buffer_list().buffers
  options = options or {}
  local win_width, _ = utils.get_win_dimensions()
  local _, file_path_col_width, _ = M.get_column_widths(win_width)

  ---@class TreeNode: table<string, TreeNode>
  local reverse_path_token_tree = {}

  for _, buffer in ipairs(buffers) do
    local curr_node = reverse_path_token_tree
    for i = #buffer.file_path_tokens, 1, -1 do
      local path_token = buffer.file_path_tokens[i]
      if curr_node[path_token] == nil then
        curr_node[path_token] = {}
      end
      curr_node = curr_node[path_token]
    end
  end

  local buf_lines = {} ---@type string[]
  ---@type {name: string, row: integer, col_start: integer, col_end: integer}[]
  local hl_locs = {}

  for i, buffer in ipairs(buffers) do
    local remaining_file_path_width = file_path_col_width
    local display_path_tokens = {} ---@type string[]
    local significant_path_length = 0
    local curr_node = reverse_path_token_tree
    for j = #buffer.file_path_tokens, 1, -1 do
      local path_token = buffer.file_path_tokens[j]
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

    for j = 1, #buffer.file_path_tokens - #display_path_tokens, 1 do
      local path_token = buffer.file_path_tokens[j]
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
    if options.hide_keymapping or buffer.key == nil then
      -- Maintain the space, but don't display the key.
      keymapping = " "
    else
      keymapping = buffer.key
    end

    table.insert(
      buf_lines,
      " " .. buffer.buf_indicators .. " " .. display_path .. " " .. keymapping
    )

    local col_start, col_end = 1, 4
    table.insert(hl_locs, {name = "BufhopperBufferIndicators", row = row, col_start = col_start, col_end = col_end})
    col_start = col_end + 1
    col_end = col_start + non_significant_path_length + 1
    table.insert(hl_locs, {name = "BufhopperDirPath", row = row, col_start = col_start, col_end = col_end})
    col_start = col_end
    col_end = col_start + significant_path_length
    table.insert(hl_locs, {name = "BufhopperFileName", row = row, col_start = col_start, col_end = col_end})
    col_start = col_end
    col_end = col_start + 1
    local mode = state.get_mode_manager().mode
    local hl_jump_key_name ---@type string
    if mode == "normal" then
      hl_jump_key_name = "BufhopperJumpKeyDisabled"
    else
      hl_jump_key_name = "BufhopperJumpKey"
    end
    table.insert(hl_locs, {name = hl_jump_key_name, row = row, col_start = col_start, col_end = col_end})

    -- local col_start, col_end = 1, 2
    -- table.insert(hl_locs, {name = "BufhopperKey", row = row, col_start = col_start, col_end = col_end})
    -- col_start = col_end + 1
    -- col_end = col_start + non_significant_path_length + 1
    -- table.insert(hl_locs, {name = "BufhopperDirPath", row = row, col_start = col_start, col_end = col_end})
    -- col_start = col_end
    -- col_end = col_start + significant_path_length
    -- table.insert(hl_locs, {name = "BufhopperFileName", row = row, col_start = col_start, col_end = col_end})

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

function BufferTable:cursor_to_buf(buf)
  local buffers = state.get_buffer_list().buffers
  for i, buffer in ipairs(buffers) do
    if buffer.buf == buf then
      vim.api.nvim_win_set_cursor(self.win, {i, 0})
      break
    end
  end
end

function BufferTable:cursor_to_row(row)
  vim.api.nvim_win_set_cursor(self.win, {row, 0})
end

function BufferTable:buffer_under_cursor()
  local buffers = state.get_buffer_list().buffers
  local cursor_pos = vim.api.nvim_win_get_cursor(self.win)
  local buffer_idx = cursor_pos[1]
  local buffer = buffers[buffer_idx] ---@type BufhopperBuffer | nil
  return buffer
end

function BufferTable:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
end

M.BufferTable = BufferTable

---@class BufhopperStatusLine
---@field buf integer
---@field win integer
---@field mode BufhopperMode | nil
---@field attach fun(float: BufhopperFloatingWindow): BufhopperStatusLine
---@field draw fun(self: BufhopperStatusLine): nil
local StatusLine = {}
StatusLine.__index = StatusLine

function StatusLine.attach(float)
  local statline = {}
  setmetatable(statline, StatusLine)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("modifiable", false, {buf = buf})
  statline.buf = buf
  local win_width, win_height = utils.get_win_dimensions()
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "win",
    win = float.win,
    width = win_width,
    height = 1,
    row = win_height - 1,
    col = 0,
    border = "none",
    focusable = false,
  }
  local win = vim.api.nvim_open_win(buf, false, win_config)
  statline.win = win
  state.set_status_line(statline)
  return statline
end

function StatusLine:draw()
  local mode = state.get_mode_manager().mode
  ---@type {name: string, row: integer, col_start: integer, col_end: integer}[]
  local hl_locs = {}
  local buf_lines = {} ---@type string[]
  local mode_indicator ---@type string
  if mode == "normal" then
    mode_indicator = "  Normal "
    table.insert(hl_locs, {name = "BufhopperModeNormal", row = 0, col_start = 1, col_end = 9})
  elseif mode == "jump" then
    mode_indicator = "  Jump "
    table.insert(hl_locs, {name = "BufhopperModeJump", row = 0, col_start = 1, col_end = 7})
  else
    vim.notify("Unrecognized mode: " .. mode, vim.log.levels.WARN)
  end

  local buflist = state.get_buffer_list()
  if buflist.total_pages > 1 then
    local page_indicator = buflist.page + 1 .."/" .. buflist.total_pages .. " "
    local pagination_indicators = "󰌥  prev, next 󰌒 "
    local win_width, _ = utils.get_win_dimensions()
    local padding = string.rep(" ", win_width - vim.fn.strdisplaywidth(mode_indicator) - vim.fn.strdisplaywidth(page_indicator) - vim.fn.strdisplaywidth(pagination_indicators))
    local prev_col_start = string.len(mode_indicator .. padding .. page_indicator)
    local prev_col_end = prev_col_start + 10
    local prev_hl_name ---@type string
    if buflist.page < 1 then
      prev_hl_name = "BufhopperPaginationDisabled"
    else
      prev_hl_name = "BufhopperPaginationEnabled"
    end
    table.insert(hl_locs, {name = prev_hl_name, row = 0, col_start = prev_col_start, col_end = prev_col_end})
    local next_col_start = prev_col_end + 2
    local next_col_end = next_col_start + 10
    local next_hl_name ---@type string
    if buflist.page + 1 >= buflist.total_pages then
      next_hl_name = "BufhopperPaginationDisabled"
    else
      next_hl_name = "BufhopperPaginationEnabled"
    end
    table.insert(hl_locs, {name = next_hl_name, row = 0, col_start = next_col_start, col_end = next_col_end})
    table.insert(buf_lines, mode_indicator .. padding .. page_indicator .. pagination_indicators)
    buflist:add_pagination_keymaps()
  else
    table.insert(buf_lines, mode_indicator)
  end

  vim.api.nvim_set_option_value("modifiable", true, {buf = self.buf})
  vim.api.nvim_buf_clear_namespace(self.buf, 0, 0, -1) -- clear highlights
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, buf_lines) -- draw lines
  for _, hl_loc in ipairs(hl_locs) do -- add highlights
    vim.api.nvim_buf_add_highlight(self.buf, 0, hl_loc.name, hl_loc.row, hl_loc.col_start, hl_loc.col_end)
  end
  vim.api.nvim_set_option_value("modifiable", false, {buf = self.buf})
  -- Force a redraw. This handles an issue where which-key stops the UI from updating until after
  -- the delayed drawer opens.
  -- vim.cmd("redraw")
end

function StatusLine:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
end

M.StatusLine = StatusLine
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
