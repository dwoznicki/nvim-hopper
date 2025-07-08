local M = {}

local function handle_command(opts)
  local subcommand = opts.fargs[1]
  if subcommand == "open" then
    error("TODO")
  elseif subcommand == "close" then
    error("TODO")
  elseif subcommand == "populate_db" then
    local conn = require("hopper.db.sqlite").Connection.new("/tmp/hopper.db")
    local pstmt = require("hopper.db.sqlite").PreparedStatement.new(
      "INSERT INTO file_mappings (project, path, keymap, created) VALUES (?, ?, ?, unixepoch())",
      conn
    )
    -- local files = vim.split(vim.fn.glob("~/enderpy/*/**"), "\n")

    local files = vim.fs.find(
      function() return true end,
      { path = "~/enderpy/", type = "file", limit = math.huge }
    )
    local datastore = require("hopper.db").datastore()
    local assigned_keymaps = require("hopper.utils").set(datastore:list_keymaps("x"))
    local allowed_keys = require("hopper.utils").set(require("hopper.options").options().files.keyset)
    for _, file in ipairs(files) do
      local keymap = require("hopper.quickfile").keymap_for_path(file, 4, allowed_keys, assigned_keymaps)
      pstmt:exec_update({"x", file, keymap})
      assigned_keymaps[keymap] = true
      print("Finished " .. file .. " " .. keymap)
    end
    -- local changed = conn:exec_update("INSERT OR REPLACE INTO projects (path) VALUES (?)", {"/abc"})
    -- vim.print("changed = " .. changed)
  elseif subcommand == "toggle_info" then
    require("hopper.actions").toggle_info()
  else
    print("Unrecognized subcommand: " .. (subcommand or "nil"))
  end
end

local function complete_subcommand(_, _, _)
  return {
    "open",
    "close",
    "populate_db",
    "toggle_info",
  }
end

---Setup ex commands. 
M.setup = function()
  vim.api.nvim_create_user_command(
    "Hopper",
    handle_command,
    {
      nargs = 1,
      complete = complete_subcommand,
      desc = "Hopper entry command",
    }
  )
end

return M
