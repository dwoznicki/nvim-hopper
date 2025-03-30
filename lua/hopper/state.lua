-- No imports!

local M = {}

---@class BufhopperState
---@field prior_current_buf integer The active buffer before float opened.
---@field prior_alternate_buf integer The alternate buffer before float opened.
---@field config BufhopperConfig | nil
---@field buffer_list BufhopperBufferList | nil
---@field floating_window BufhopperFloatingWindow | nil
---@field buffer_table BufhopperBufferTable | nil
---@field status_line BufhopperStatusLine | nil
---@field mode_manager BufhopperModeManager | nil

---@type BufhopperState
M.current = {
  prior_current_buf = vim.api.nvim_get_current_buf(),
  prior_alternate_buf = vim.fn.bufnr("#"),
  config = nil,
  buffer_list = nil,
  floating_window = nil,
  buffer_table = nil,
  status_line = nil,
  mode_manager = nil,
}

---@return integer
function M.get_prior_current_buf()
  return M.current.prior_current_buf
end

---@param buf? integer defaults to `vim.api.nvim_get_current_buf()`
function M.set_prior_current_buf(buf)
  if buf == nil then
    buf = vim.api.nvim_get_current_buf()
  end
  M.current.prior_current_buf = buf
end

---@return integer
function M.get_prior_alternate_buf()
  return M.current.prior_alternate_buf
end

---@param buf? integer defaults to `vim.fn.bufnr("#")`
function M.set_prior_alternate_buf(buf)
  if buf == nil then
    buf = vim.fn.bufnr("#")
  end
  M.current.prior_alternate_buf = buf
end
---@return BufhopperConfig
function M.get_config()
  if M.current.config == nil then
    error("Bufhopper config not set.")
  end
  return M.current.config
end

---@param config BufhopperConfig
function M.set_config(config)
  M.current.config = config
end

---@return BufhopperBufferList
function M.get_buffer_list()
  if M.current.buffer_list == nil then
    error("Bufhopper buffer list not set.")
  end
  return M.current.buffer_list
end

---@param buflist BufhopperBufferList
function M.set_buffer_list(buflist)
  M.current.buffer_list = buflist
end

---@return BufhopperFloatingWindow
function M.get_floating_window()
  if M.current.floating_window == nil then
    error("Bufhopper floating window not set.")
  end
  return M.current.floating_window
end

---@param float BufhopperFloatingWindow
function M.set_floating_window(float)
  M.current.floating_window = float
end

function M.clear_floating_window()
  M.current.floating_window = nil
end

---@return BufhopperBufferTable
function M.get_buffer_table()
  if M.current.buffer_table == nil then
    error("Bufhopper buffer table not set.")
  end
  return M.current.buffer_table
end

---@param buftable BufhopperBufferTable
function M.set_buffer_table(buftable)
  M.current.buffer_table = buftable
end

function M.clear_buffer_table()
  M.current.buffer_table = nil
end

---@return BufhopperStatusLine
function M.get_status_line()
  if M.current.status_line == nil then
    error("Bufhopper status line not set.")
  end
  return M.current.status_line
end

---@param statline BufhopperStatusLine
function M.set_status_line(statline)
  M.current.status_line = statline
end


---@return BufhopperModeManager
function M.get_mode_manager()
  if M.current.mode_manager == nil then
    error("Bufhopper mode manager not set.")
  end
  return M.current.mode_manager
end

---@param mode_manager BufhopperModeManager
function M.set_mode_manager(mode_manager)
  M.current.mode_manager = mode_manager
end

function M.clear_mode_manager()
  M.current.mode_manager = nil
end

return M
