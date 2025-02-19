local state = require("bufhopper.state")
local keysets = require("bufhopper.keysets")
local filepath = require("bufhopper.filepath")

local M = {}

---@class BufhopperBuffer
---@field key string
---@field buf integer
---@field file_name string
---@field file_path string
---@field file_path_tokens string[]
---@field buf_indicators string

---@class BufhopperBufferList
---@field pinned_buffers BufhopperBuffer[]
---@field buffers BufhopperBuffer[]
---@field create fun(): BufhopperBufferList
---@field remove_index fun(self: BufhopperBufferList, idx: integer): nil
---@field remove_index_range fun(self: BufhopperBufferList, start_idx: integer, end_idx: integer): nil
local BufferList = {}
BufferList.__index = BufferList

function BufferList.create()
  local buflist = {}
  setmetatable(buflist, BufferList)
  buflist:populate()
  state.set_buffer_list(buflist)
  return buflist
end

function BufferList:populate()
  local config = state.get_config()
  ---@type BufhopperBuffer[]
  local buffers = {}
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
      buffers,
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
  table.sort(buffers, function(a, b)
    return a.buf < b.buf
  end)
  self.buffers = buffers
  self.pinned_buffers = {} -- TODO
end

function BufferList:remove_index(idx)
  local buffer = self.buffers[idx]
  vim.api.nvim_buf_delete(buffer.buf, {})
  table.remove(self.buffers, idx)
end


function BufferList:remove_index_range(start_idx, end_idx)
  for i = end_idx, start_idx, -1 do
    local buffer = self.buffers[i]
    vim.api.nvim_buf_delete(buffer.buf, {})
    table.remove(self.buffers, i)
  end
end

M.BufferList = BufferList

---@param buf integer
---@param current_buf integer
---@param alternate_buf integer
---@return string
function M.get_buffer_indicators(buf, current_buf, alternate_buf)
  local buf_info = vim.fn.getbufinfo(buf)[1]
  ---@type string
  local ind1
  if buf == current_buf then
    ind1 = "%"
  elseif buf == alternate_buf then
    ind1 = "#"
  else
    ind1 = " "
  end
  ---@type string
  local ind2
  if #buf_info.windows > 0 then
    ind2 = "a"
  elseif buf_info.hidden == 1 then
    ind2 = "h"
  else
    ind2 = " "
  end
  ---@type string
  local ind3
  if buf_info.changed == 1 then
    ind3 = "+"
  else
    ind3 = " "
  end
  return ind1 .. ind2 .. ind3
end

return M
