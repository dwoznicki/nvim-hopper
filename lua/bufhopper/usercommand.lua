local actions = require("bufhopper.actions")

local M = {}

local function handle_command(opts)
  local subcommand = opts.fargs[1]
  if subcommand == "open" then
    actions.open(M.config)
  elseif subcommand == "close" then
    actions.close()
  elseif subcommand == "delete_other_buffers" then
    actions.delete_other_buffers()
  else
    print("Unrecognized subcommand: " .. (subcommand or "nil"))
  end
end

local function complete_subcommand(_, _, _)
  return {
    "open",
    "close",
    "delete_other_buffers",
  }
end

---Setup ex commands. 
---@param config BufhopperConfig
M.setup = function(config)
  M.config = config
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
