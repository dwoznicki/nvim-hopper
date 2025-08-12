local sqlite = require("hopper.db.sqlite")

local M = {}

---@type hopper.SqlDatastore | nil
local datastore = nil

---@return hopper.SqlDatastore
function M.datastore()
  if datastore == nil then
    local db_path = require("hopper.options").options().db.database_path
    datastore = sqlite.SqlDatastore.new(db_path)
    datastore:init()
  end
  return datastore
end

return M
