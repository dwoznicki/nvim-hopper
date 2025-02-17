-- No imports!

local M = {}

---@class BufhopperState
---@field config BufhopperConfig | nil
---@field float BufhopperFloatingWindow | nil
---@field buflist BufhopperBufferList | nil
---@field mode_manager BufhopperModeManager | nil

---@type BufhopperState
M.current = {
  config = nil,
  float = nil,
  buflist = nil,
  mode_manager = nil,
}
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

---@return BufhopperFloatingWindow
function M.get_float()
  if M.current.float == nil then
    error("Bufhopper floating window not set.")
  end
  return M.current.float
end

---@param float BufhopperFloatingWindow
function M.set_float(float)
  M.current.float = float
end

function M.clear_float()
  M.current.float = nil
end

---@return BufhopperBufferList
function M.get_buflist()
  if M.current.buflist == nil then
    error("Bufhopper buffer list not set.")
  end
  return M.current.buflist
end

---@param buflist BufhopperBufferList
function M.set_buflist(buflist)
  M.current.buflist = buflist
end

function M.clear_buflist()
  M.current.buflist = nil
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
