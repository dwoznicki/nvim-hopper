-- No imports!

local M = {}

---@param width integer | decimal
---@param height integer | decimal
---@return integer width, integer height
function M.get_win_dimensions(width, height)
  local ui = vim.api.nvim_list_uis()[1]
  local win_width ---@type integer
  if width < 1 then
    win_width = math.ceil(ui.width * width)
  else
    win_width = width
  end
  local win_height ---@type integer
  if height < 1 then
    win_height = math.ceil(ui.height * height)
  else
    win_height = height
  end
  return win_width, win_height
  -- local width = math.ceil(ui.width * 0.5)
  -- -- For height, we'll try and choose a reasonable value without going over the available
  -- -- remaining space.
  -- local height = math.max(math.ceil(ui.height * 0.6), 16)
  -- return width, height
end

---@param list string[]
---@return table<string, true>
function M.set(list)
  local set = {}
  for _, value in ipairs(list) do
    set[value] = true
  end
  return set
end

---@generic T
---@param tbl `T`
---@return T
function M.readonly(tbl)
  local proxy = {}
  local metatbl = {
    __index = tbl,
    __newindex = function(t, key, val)
      error("Attempted to update a readonly table.", 2)
    end
  }
  setmetatable(proxy, metatbl)
  return proxy
end

---@generic T
---@param tbl T[]
---@return T[]
function M.sorted(tbl)
  ---@generic T
  local tbl_copy = {} ---@type T[]
  for i, item in ipairs(tbl) do
    tbl_copy[i] = item
  end
  table.sort(tbl_copy)
  return tbl_copy
end

---@param buf integer
---@param num_chars integer
---@return string
-- Clamp buffer value to given number of characters and return result.
-- Only one line is supported.
function M.clamp_buffer_value_chars(buf, num_chars)
  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count > 1 then
    vim.api.nvim_buf_set_lines(buf, 1, -1, false, {})
  end
  local value = vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] or ""
  if num_chars ~= nil and string.len(value) > num_chars then
    value = value:sub(1, num_chars)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {value})
  end
  return value
end

---@class hopper.ClampBufferValueLinesOpts
---@field exact? boolean If true, enforce exactly this number of lines, adding blanks if necessary.

---@param buf integer
---@param num_lines integer
---@param opts? hopper.ClampBufferValueLinesOpts
---@return string[]
-- Clamp buffer value to given number of lines and return result.
function M.clamp_buffer_value_lines(buf, num_lines, opts)
  opts = opts or {}
  local line_count = vim.api.nvim_buf_line_count(buf)

  if opts.exact then
    if line_count < num_lines then
      -- Append blanks until we reach num_lines
      local blanks = {}
      for _ = 1, num_lines - line_count do
        blanks[#blanks+1] = ""
      end
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, blanks)
      line_count = num_lines
    elseif line_count > num_lines then
      -- Delete surplus lines (0-based start index)
      vim.api.nvim_buf_set_lines(buf, num_lines, -1, false, {})
      line_count = num_lines
    end
  else
    if line_count > num_lines then
      vim.api.nvim_buf_set_lines(buf, num_lines, -1, false, {})
      line_count = num_lines
    end
    -- If count < num_lines, we **do nothing** (no padding) in non-exact mode
  end

  -- Always guarantee at least ONE line so extmarks at (0,0) are valid.
  -- (Only needed if someone calls with num_lines == 0 or an empty new buffer
  -- and exact=false.)
  if vim.api.nvim_buf_line_count(buf) == 0 then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {""})
  end

  -- Return up to num_lines (or current count if smaller)
  local to = math.min(num_lines, vim.api.nvim_buf_line_count(buf))
  return vim.api.nvim_buf_get_lines(buf, 0, to, false)
end

---@param value any
---@return boolean
function M.is_integer(value)
  return type(value) == "number" and math.floor(value) == value
end

---@class hopper.OpenOrFofucsFileOptions
---@field open_cmd string | nil

---@param path string
---@param opts? hopper.OpenOrFofucsFileOptions
---@return integer buf
function M.open_or_focus_file(path, opts)
  opts = opts or {}
  local open_cmd = opts.open_cmd or "edit"
  local abs_path = vim.fn.fnamemodify(path, ":p")
  local buf = vim.fn.bufnr(abs_path)

  if buf == -1 then
    -- Not in buflist yet. Open new buffer.
    vim.cmd(string.format("%s %s", open_cmd, vim.fn.fnameescape(abs_path)))
    return vim.api.nvim_get_current_buf()
  end

  -- Buffer exists. If a window already shows it, jump there.
  local wins = vim.fn.win_findbuf(buf)
  if #wins > 0 then
    vim.api.nvim_set_current_win(wins[1])
    return buf
  end

  -- Otherwise, show it in current window (or a new split/tab).
  if open_cmd ~= "edit" then
    vim.cmd(open_cmd)
  end
  vim.api.nvim_set_current_buf(buf)
  return buf
end

---@class hopper.AttachCloseEventsOptions
---@field buffer integer
---@field on_close fun()
---@field keypress_events string[]
---@field vim_change_events string[]

---@param opts hopper.AttachCloseEventsOptions
function M.attach_close_events(opts)
  for _, key in ipairs(opts.keypress_events) do
    vim.keymap.set(
      "n",
      key,
      opts.on_close,
      {noremap = true, silent = true, nowait = true, buffer = opts.buffer}
    )
  end

  vim.api.nvim_create_autocmd(opts.vim_change_events, {
    buffer = opts.buffer,
    once = true,
    callback = function()
      vim.schedule(opts.on_close)
    end,
  })

end

return M
