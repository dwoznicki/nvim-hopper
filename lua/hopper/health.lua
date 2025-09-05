local options = require("hopper.options")
local sqlite_db = require("hopper.db.sqlite")

local M = {}

function M.check()
  vim.health.start("Checking database health")
  local db_ok = true
  local opts = options.options()
  -- Check that sqlite is installed.
  local sqlite_bin = opts.db.sqlite_path
  if vim.fn.executable(sqlite_bin) == 0 then
    vim.health.error(
      string.format("Unable to find sqlite3 binary at \"%s\".", sqlite_bin),
      {
        "If sqlite3 is installed in a different location, you can provide that to Hopper via `options.db.sqlite_path` when calling setup."
      }
    )
    db_ok = false
  end
  -- Check that sqlite3 database file is properly created.
  local db_path = opts.db.database_path
  sqlite_db.SqlDatastore.new(db_path)
  if vim.fn.filereadable(db_path) == 0 then
    vim.health.error(
      string.format("Unable to find sqlite3 database file at \"%s\".", db_path)
    )
    db_ok = false
  end
  -- Now we'll run some common operations to make sure they all succeed. To isolate from the default
  -- data set, we'll write to a different location.
  local tmp_db_path = vim.fn.tempname() .. ".db"
  local tmp_datastore = sqlite_db.SqlDatastore.new(tmp_db_path)
  local ok ---@type boolean
  local result ---@type any
  -- Initialize database schema.
  ok, result = pcall(tmp_datastore.init, tmp_datastore)
  if not ok then
    vim.health.error(
      string.format("Unable to initialize database schema. %s", result)
    )
    db_ok = false
  end
  -- Create a project.
  ok, result = pcall(tmp_datastore.set_project, tmp_datastore, "tmp", "/tmp")
  if not ok then
    vim.health.error(
      string.format("Unable to write project to database. %s", result)
    )
    db_ok = false
  end
  -- Select projects.
  ok, result = pcall(tmp_datastore.list_projects, tmp_datastore)
  if not ok then
    vim.health.error(
      string.format("Unable to read projects from database. %s", result)
    )
    db_ok = false
  end
  -- Create a file keymap.
  ok, result = pcall(tmp_datastore.set_file_keymap, tmp_datastore, "tmp", "dummy", "du")
  if not ok then
    vim.health.error(
      string.format("Unable to write file keymap to database. %s", result)
    )
    db_ok = false
  end
  -- Select file keymaps.
  ok, result = pcall(tmp_datastore.list_file_keymaps, tmp_datastore, "tmp")
  if not ok then
    vim.health.error(
      string.format("Unable to read file keymap from database. %s", result)
    )
    db_ok = false
  end
  if db_ok then
    vim.health.ok("Database health ok")
  end

  vim.health.start("Checking options health")
end

return M
