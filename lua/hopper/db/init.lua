local sqlite = require("hopper.db.sqlite")

local M = {}

---@type hopper.SqlDatastore | nil
local datastore = nil

---@return hopper.SqlDatastore
function M.datastore()
  if datastore == nil then
    datastore = sqlite.SqlDatastore.new(sqlite.DEFAULT_DB_PATH)
    datastore:init()
  end
  return datastore
end

return M
