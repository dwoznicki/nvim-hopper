local M = {}

local function readonly(t)
  local proxy = {}
  local mt = {
    __index = t,
    __newindex = function (_, _, _)
      error("Attempted to update a read-only table.", 2)
    end
  }
  setmetatable(proxy, mt)
  return proxy
end

M.alpha = readonly({
  "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
})
M.numeric = readonly({
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
})
M.ergonomic = readonly({
  "a", "s", "d", "f", "j", "k", "l", "q", "w", "e", "r", "t", "u", "i", "o", "p", "z", "x", "c", "v", "b", "n", "m", "g", "h", "y",
})

return M
