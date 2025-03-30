local M = {}

local function handle_command(opts)
  local subcommand = opts.fargs[1]
  if subcommand == "open" then
    error("TODO")
  elseif subcommand == "close" then
    error("TODO")
  elseif subcommand == "delete_other_buffers" then
    error("TODO")
  elseif subcommand == "init_datastore" then
    require("bufhopper.datastore").init("/tmp/hopper.db")
  elseif subcommand == "insert" then
    local conn = require("bufhopper.datastore").Connection.new("/tmp/hopper.db")
    local changed = conn:exec_update("INSERT OR REPLACE INTO projects (path) VALUES (?)", {"/abc"})
    vim.print("changed = " .. changed)
  elseif subcommand == "select" then
    local conn = require("bufhopper.datastore").Connection.new("/tmp/hopper.db")
    local results = conn:exec_query("SELECT * FROM projects")
    vim.print(results)
  else
    print("Unrecognized subcommand: " .. (subcommand or "nil"))
  end
end

local function complete_subcommand(_, _, _)
  return {
    "open",
    "close",
    "delete_other_buffers",
    "init_datastore",
    "insert",
    "select",
  }
end

---Setup ex commands. 
M.setup = function()
  vim.api.nvim_create_user_command(
    "Bufhopper",
    handle_command,
    {
      nargs = 1,
      complete = complete_subcommand,
      desc = "Bufhopper entry command",
    }
  )
end

return M
