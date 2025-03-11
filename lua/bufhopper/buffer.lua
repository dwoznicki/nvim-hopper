local state = require("bufhopper.state")
local keysets = require("bufhopper.keysets")
local filepath = require("bufhopper.filepath")
local utils = require("bufhopper.utils")
local set = utils.set

local M = {}

---@class BufhopperBuffer
---@field key string | nil
---@field buf integer
---@field file_name string
---@field file_path string
---@field file_path_tokens string[]
---@field buf_indicators string

---@class BufhopperBufferList
---@field pinned_buffers BufhopperBuffer[]
---@field buffers BufhopperBuffer[]
---@field page integer default = 0
---@field total_pages integer default = 1
---@field buffers_by_key table<string, BufhopperBuffer | -1>
---@field create fun(): BufhopperBufferList
---@field remove_at_index fun(self: BufhopperBufferList, idx: integer): nil
---@field remove_in_index_range fun(self: BufhopperBufferList, start_idx: integer, end_idx: integer): nil
local BufferList = {}
BufferList.__index = BufferList

function BufferList.create()
  local buflist = {}
  setmetatable(buflist, BufferList)
  buflist.page = 0
  buflist.total_pages = 1
  buflist:populate()
  state.set_buffer_list(buflist)
  return buflist
end

function BufferList:populate()
  local config = state.get_config()
  local bufs = {} ---@type integer[]
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if (vim.api.nvim_buf_is_loaded(buf) or config.buffers.show_unloaded)
      and (vim.bo[buf].buflisted or config.buffers.show_hidden)
    then
      table.insert(bufs, buf)
    end
  end

  if config.buffers.paginate then
    local _, win_height = utils.get_win_dimensions()
    local page_size = win_height - 3
    self.total_pages = math.ceil(#bufs / page_size)
    local page_start = (self.page * page_size) + 1
    if #bufs < page_start then
      vim.notify("Page is out or range. Resetting to page 1.", vim.log.levels.INFO)
      self.page = 0
      page_start = 1
    end
    local page_end = page_start + page_size
    bufs = vim.list_slice(bufs, page_start, page_end)
  end

  local keyset = keysets.determine_keyset(config.keyset)

  local prev_key = nil ---@type string | nil
  local mapped_keys = {} ---@type table<string, integer>
  local remaining_keys = set(keyset) ---@type table<string, true>
  ---@type BufhopperNextKeyContext
  local next_key_context = {
    config = config,
    keyset = keyset,
    mapped_keys = mapped_keys,
    remaining_keys = remaining_keys,
    prev_key = prev_key,
    keyset_index = 1,
    file_name = "",
  }

  local current_buf = state.get_prior_current_buf()
  local alternate_buf = state.get_prior_alternate_buf()

  local buffers_by_key = {} ---@type table<string, BufhopperBuffer | -1>
  for _, key in ipairs(keyset) do
    buffers_by_key[key] = -1
  end
  local buffers = {} ---@type BufhopperBuffer[]
  for _, buf in ipairs(bufs) do
    local project_file_path = filepath.get_path_from_project_root(vim.api.nvim_buf_get_name(buf))
    local project_file_path_tokens = vim.split(project_file_path, "/")
    local file_name = vim.fn.fnamemodify(project_file_path, ":t")
    local buf_indicators = M.get_buffer_indicators(buf, current_buf, alternate_buf)
    next_key_context.file_name = file_name

    local key = nil ---@type string | nil
    if type(config.next_key) == "function" then
      --- LuaLS gets this wrong.
      ---@diagnostic disable-next-line: cast-local-type
      key = config.next_key(next_key_context)
    elseif config.next_key == "filename" then
      key = keysets.next_key_filename(next_key_context)
    elseif config.next_key == "sequential" then
      key = keysets.next_key_sequential(next_key_context)
      next_key_context.keyset_index = next_key_context.keyset_index + 1
    end
    next_key_context.prev_key = key
    if key ~= nil then
      mapped_keys[key] = buf
      remaining_keys[key] = nil
    end

    ---@type BufhopperBuffer
    local buffer = {
      key = key,
      buf = buf,
      file_name = file_name,
      file_path = project_file_path,
      file_path_tokens = project_file_path_tokens,
      buf_indicators = buf_indicators,
    }
    table.insert(buffers, buffer)
    if key ~= nil then
      buffers_by_key[key] = buffer
    end
  end
  table.sort(buffers, function(a, b)
    return a.buf < b.buf
  end)
  self.buffers = buffers
  self.pinned_buffers = {} -- TODO
  self.buffers_by_key = buffers_by_key
end

function BufferList:remove_at_index(idx)
  local deleting_buffer = self.buffers[idx]
  local displaying_wins = M.get_wins_displaying_buf(deleting_buffer.buf)
  if #displaying_wins > 0 then
    local backup_buf = M.get_backup_display_buf(deleting_buffer.buf)
    for _, win in ipairs(displaying_wins) do
      vim.api.nvim_win_set_buf(win, backup_buf)
    end
  end
  vim.api.nvim_buf_delete(deleting_buffer.buf, {})
  table.remove(self.buffers, idx)
  self.buffers_by_key[deleting_buffer.key] = nil
end

function BufferList:remove_in_index_range(start_idx, end_idx)
  for i = end_idx, start_idx, -1 do
    self:remove_at_index(i)
  end
end

function BufferList:add_pagination_keymaps()
  local buftable = state.get_buffer_table()

  vim.keymap.set(
    "n",
    "<tab>",
    function()
      local next_page = self.page + 1
      vim.print("next_page", next_page)
      if next_page >= self.total_pages then
        return
      end
      self.page = next_page
      self:populate()
      state.get_buffer_table():draw()
      state.get_status_line():draw()
    end,
    {silent = true, nowait = true, buffer = buftable.buf}
  )
  vim.keymap.set(
    "n",
    "<S-tab>",
    function()
      local prev_page = self.page - 1
      vim.print("prev_page", prev_page)
      if prev_page < 0 then
        return
      end
      self.page = prev_page
      self:populate()
      state.get_buffer_table():draw()
      state.get_status_line():draw()
    end,
    {silent = true, nowait = true, buffer = buftable.buf}
  )
end

M.BufferList = BufferList

---@param buf integer
---@param current_buf integer
---@param alternate_buf integer
---@return string
function M.get_buffer_indicators(buf, current_buf, alternate_buf)
  local buf_info = vim.fn.getbufinfo(buf)[1]
  local ind1 ---@type string
  if buf == current_buf then
    ind1 = "%"
  elseif buf == alternate_buf then
    ind1 = "#"
  else
    ind1 = " "
  end
  local ind2 ---@type string
  if #buf_info.windows > 0 then
    ind2 = "a"
  elseif buf_info.hidden == 1 then
    ind2 = "h"
  else
    ind2 = " "
  end
  local ind3 ---@type string
  if buf_info.changed == 1 then
    ind3 = "+"
  else
    ind3 = " "
  end
  return ind1 .. ind2 .. ind3
end

---@param buf integer
---@return integer[] wins
function M.get_wins_displaying_buf(buf)
  local buf_info = vim.fn.getbufinfo(buf)[1]
  return buf_info.windows
end

---Get best backup buffer to display in windows that are currently displaying buf. If no candidates
---are found, this function will create and return a fallback scratch buffer.
---@param buf integer
---@return integer backup_buf
function M.get_backup_display_buf(buf)
  -- First, try the current buf from before the float was opened.
  local backup_buf = state.get_prior_current_buf()
  if backup_buf ~= buf and vim.api.nvim_buf_is_valid(backup_buf) then
    return backup_buf
  end
  -- Second, try the alternate buf from before the float was opened.
  backup_buf = state.get_prior_alternate_buf()
  if backup_buf ~= buf and vim.api.nvim_buf_is_valid(backup_buf) then
    return backup_buf
  end
  -- Next, try the buf after the given buf sequentially.
  local next_best_candidate_buf = -1
  for _, backup_candidate_buf in ipairs(vim.api.nvim_list_bufs()) do
    local buftype = vim.api.nvim_get_option_value("buftype", {buf = backup_candidate_buf})
    if buftype ~= "nofile" and vim.api.nvim_buf_is_valid(backup_candidate_buf) then
      if backup_candidate_buf > buf then
        return backup_candidate_buf
      end
      if backup_candidate_buf < buf then
        next_best_candidate_buf = backup_candidate_buf
      end
    end
  end
  -- There were no good buffers opened after the given buf. Try the buf directly before it.
  if vim.api.nvim_buf_is_valid(next_best_candidate_buf) then
    return next_best_candidate_buf
  end
  -- If we get here, we have failed to find a decent fallback buffer. This is probably because the
  -- given buffer is the last valid buffer in the session. As a final fallback, create a scratch
  -- buffer and return it.
  local fallback_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = fallback_buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = fallback_buf})
  return fallback_buf
end

return M
