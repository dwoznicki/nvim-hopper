local M = {}

M.default_config = function()
  return {
    keyset = "ergonomic",
    next_key = "filename",
  }
end

---@type BufhopperConfigState
M.state = M.default_config()


return M
