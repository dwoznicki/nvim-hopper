local ffi = require("ffi")

ffi.cdef([[
  typedef struct sqlite3 sqlite3;
  typedef struct sqlite3_stmt sqlite3_stmt;
  typedef void (*sqlite3_destructor_type)(void*);

  int sqlite3_open(const char *filename, sqlite3 **ppDb);
  int sqlite3_close(sqlite3*);
  int sqlite3_exec(sqlite3*, const char *sql, int (*callback)(void*, int, char**, char**), void*, char **errmsg);
  int sqlite3_prepare_v2(sqlite3*, const char *zSql, int nByte, sqlite3_stmt **ppStmt, const char **pzTail);
  int sqlite3_reset(sqlite3_stmt*);
  int sqlite3_clear_bindings(sqlite3_stmt*);
  int sqlite3_step(sqlite3_stmt*);
  int sqlite3_finalize(sqlite3_stmt*);
  int sqlite3_bind_parameter_count(sqlite3_stmt*);
  int sqlite3_bind_text(sqlite3_stmt*, int, const char*, int n, void(*)(void*));
  int sqlite3_bind_int64(sqlite3_stmt*, int, long long);
  const unsigned char *sqlite3_column_text(sqlite3_stmt*, int);
  long long sqlite3_column_int64(sqlite3_stmt*, int);
  int sqlite3_column_count(sqlite3_stmt*);
  int sqlite3_changes(sqlite3*);
  const char* sqlite3_errmsg(sqlite3*);
]])

local SQLITE_STATIC = ffi.cast("sqlite3_destructor_type", 0)
local SQLITE_TRANSIENT = ffi.cast("sqlite3_destructor_type", -1)

local function sqlite3_lib()
  if jit.os ~= "Windows" then
    return "sqlite3"
  end
  local sqlite_path = vim.fn.stdpath("cache") .. "\\sqlite3.dll"
  if vim.fn.filereadable(sqlite_path) == 0 then
    vim.notify("Downloading `sqlite3.dll`", vim.log.levels.INFO)
    local url = ("https://www.sqlite.org/2025/sqlite-dll-win-%s-3480000.zip"):format(jit.arch)
    local out = vim.fn.system({
      "powershell",
      "-Command",
      [[
        $url = "]] .. url .. [[";
        $zipPath = "$env:TEMP\sqlite.zip";
        $extractPath = "$env:TEMP\sqlite";
        Invoke-WebRequest -Uri $url -OutFile $zipPath;
        Add-Type -AssemblyName System.IO.Compression.FileSystem;
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractPath);

        $dllPath = "$extractPath\sqlite3.dll";
        if (Test-Path $dllPath) {
            Move-Item -Path $dllPath -Destination "]] .. sqlite_path .. [[" -Force;
        } else {
            Write-Host "sqlite3.dll not found at $dllPath";
        }
      ]],
    })
    if vim.v.shell_error ~= 0 then
      vim.notify("Failed to download `sqlite3.dll`:\n" .. out, vim.log.levels.ERROR)
    else
      vim.notify("Downloaded `sqlite3.dll`", vim.log.levels.INFO)
    end
  end
  return sqlite_path
end

local sqlite = ffi.load(sqlite3_lib())

---@alias sqlite3* ffi.cdata*
---@alias sqlite3_stmt* ffi.cdata*

---@param stmt ffi.cdata*
---@param idx number
---@param value any
---@param value_type? type
local function bind(stmt, idx, value, value_type)
  value_type = value_type or type(value)
  if value_type == "string" then
    return sqlite.sqlite3_bind_text(stmt, idx, value, #value, SQLITE_STATIC)
  elseif value_type == "number" then
    return sqlite.sqlite3_bind_int64(stmt, idx, value)
  elseif value_type == "boolean" then
    return sqlite.sqlite3_bind_int64(stmt, idx, value and 1 or 0)
  else
    error(string.format(
      "Unsupported value type: %s, \"%s\"",
      type(value),
      tostring(value)
    ))
  end
end

local M = {}

-- Probably `~/.local/share/nvim/hopper/hopper.db`.
M.DEFAULT_DB_PATH = vim.fn.stdpath("data") .. "/hopper/hopper.db"
if jit.os ~= "Windows" then
  M.DEFAULT_SQLITE_PATH = "sqlite3"
else
  M.DEFAULT_SQLITE_PATH = vim.fn.stdpath("cache") .. "\\sqlite3.dll"
end

---@class hopper.Connection
---@field sqlite_conn ffi.cdata*
local Connection = {}
Connection.__index = Connection
M.Connection = Connection

---@param path string
function Connection.new(path)
  local conn = setmetatable({}, Connection)
  local sqlite_conn = ffi.new("sqlite3*[1]")
  conn.sqlite_conn = sqlite_conn
  if sqlite.sqlite3_open(path, sqlite_conn) ~= 0 then
    error("Failed to open database: " .. path)
  end
  ffi.gc(sqlite_conn, function()
    conn:close()
  end)
  return conn
end

function Connection:close()
  local conn_ptr = self.sqlite_conn[0]
  if conn_ptr then
    sqlite.sqlite3_close(conn_ptr)
    self.sqlite_conn = nil
  end
end

---@class hopper.PreparedStatement
---@field sql string
---@field conn hopper.Connection
---@field sqlite_stmt ffi.cdata*
local PreparedStatement = {}
PreparedStatement.__index = PreparedStatement
M.PreparedStatement = PreparedStatement

---@param sql string
---@param conn hopper.Connection
function PreparedStatement.new(sql, conn)
  local pstmt = setmetatable({}, PreparedStatement)
  pstmt.sql = sql
  pstmt.conn = conn
  local conn_ptr = conn.sqlite_conn[0]
  local sqlite_stmt = ffi.new("sqlite3_stmt*[1]")
  pstmt.sqlite_stmt = sqlite_stmt
  local code = sqlite.sqlite3_prepare_v2(conn_ptr, sql, #sql, sqlite_stmt, nil)
  if code ~= 0 then
    local err = pstmt:_last_sqlite_error()
    error(string.format(
      "Failed to prepare statement. sqlite#%d: %s",
      code,
      err
    ))
  end
  ffi.gc(sqlite_stmt, function()
    pstmt:close()
  end)
  return pstmt
end

---@param binds? any[]
---@return string[][]
function PreparedStatement:exec_query(binds)
  local stmt_ptr = self.sqlite_stmt[0]
  sqlite.sqlite3_reset(stmt_ptr)
  sqlite.sqlite3_clear_bindings(stmt_ptr)
  if binds then
    local param_count = sqlite.sqlite3_bind_parameter_count(stmt_ptr)
    if param_count ~= #binds then
      error(string.format(
        "Wrong number of parameters to bind. Exepected %d, but found %d.",
        param_count,
        #binds
      ))
    end
    for i, value in ipairs(binds) do
      local code = bind(stmt_ptr, i, value)
      if code ~= 0 then
        local err = self:_last_sqlite_error()
        error(string.format(
          "Failed to find parameter %d with value \"%s\". sqlite#%d: %s",
          i,
          tostring(value),
          code,
          err
        ))
      end
    end
  end

  local results = {}

  local col_count = sqlite.sqlite3_column_count(stmt_ptr)

  while true do
    local code = sqlite.sqlite3_step(stmt_ptr)
    if code == 100 then  -- SQLITE_ROW
      local row = {}
      for i = 0, col_count - 1 do
        local col_text = sqlite.sqlite3_column_text(stmt_ptr, i)
        row[i + 1] = col_text and ffi.string(col_text) or nil
      end
      table.insert(results, row)
    elseif code == 101 then  -- SQLITE_DONE
      break
    else
      local err = self:_last_sqlite_error()
      -- sqlite.sqlite3_finalize(stmt_ptr)
      error(string.format(
        "Error iterating database rows. sqlite#%d: %s",
        code,
        err
      ))
    end
  end

  -- sqlite.sqlite3_finalize(stmt_ptr)
  return results
end

---@param binds? any[]
---@return integer
function PreparedStatement:exec_update(binds)
  local stmt_ptr = self.sqlite_stmt[0]
  sqlite.sqlite3_reset(stmt_ptr)
  sqlite.sqlite3_clear_bindings(stmt_ptr)
  if binds then
    local param_count = sqlite.sqlite3_bind_parameter_count(stmt_ptr)
    if param_count ~= #binds then
      error(string.format(
        "Wrong number of parameters to bind. Exepected %d, but found %d.",
        param_count,
        #binds
      ))
    end
    for i, value in ipairs(binds) do
      local code = bind(stmt_ptr, i, value)
      if code ~= 0 then
        local err = self:_last_sqlite_error()
        error(string.format(
          "Failed to find parameter %d with value \"%s\". sqlite#%d: %s",
          i,
          tostring(value),
          code,
          err
        ))
      end
    end
  end

  local code = sqlite.sqlite3_step(stmt_ptr)
  if code ~= 101 then  -- SQLITE_DONE
    local err = self:_last_sqlite_error()
    error(string.format(
      "Failed to execute statement. sqlite#%d: %s",
      code,
      err
    ))
  end

  -- sqlite3_changes returns the number of rows affected by the last operation.
  return sqlite.sqlite3_changes(self.conn.sqlite_conn[0])
end

function PreparedStatement:close()
  local stmt_ptr = self.sqlite_stmt[0]
  if stmt_ptr then
    sqlite.sqlite3_finalize(stmt_ptr)
    sqlite.sqlite3_close(stmt_ptr)
    self.sqlite_stmt = nil
  end
end

---@return string
function PreparedStatement:_last_sqlite_error()
  local conn_ptr = self.conn.sqlite_conn[0]
  local raw_err = sqlite.sqlite3_errmsg(conn_ptr)
  return ffi.string(raw_err)
end

---@class hopper.SqlDatastore
---@field conn hopper.Connection
---@field select_projects_stmt hopper.PreparedStatement | nil
---@field select_project_by_name_stmt hopper.PreparedStatement | nil
---@field select_project_by_path_stmt hopper.PreparedStatement | nil
---@field create_projects_table_stmt hopper.PreparedStatement | nil
---@field create_file_keymaps_table_stmt hopper.PreparedStatement | nil
---@field create_file_keymaps_project_idx_stmt hopper.PreparedStatement | nil
---@field insert_project_stmt hopper.PreparedStatement | nil
---@field update_project_stmt hopper.PreparedStatement | nil
---@field delete_project_stmt hopper.PreparedStatement | nil
---@field select_files_with_project_and_keymap_len_stmt hopper.PreparedStatement | nil
---@field select_files_with_project_stmt hopper.PreparedStatement | nil
---@field select_files_with_keymap_len_stmt hopper.PreparedStatement | nil
---@field select_files_stmt hopper.PreparedStatement | nil
---@field select_keymaps_stmt hopper.PreparedStatement | nil
---@field select_file_id_by_path_stmt hopper.PreparedStatement | nil
---@field select_file_by_keymap_stmt hopper.PreparedStatement | nil
---@field select_file_by_path_stmt hopper.PreparedStatement | nil
---@field insert_file_stmt hopper.PreparedStatement | nil
---@field update_file_stmt hopper.PreparedStatement | nil
---@field delete_file_stmt hopper.PreparedStatement | nil
---@field delete_files_for_project_stmt hopper.PreparedStatement | nil
local SqlDatastore = {}
SqlDatastore.__index = SqlDatastore
M.SqlDatastore = SqlDatastore

---@param path string
function SqlDatastore.new(path)
  local datastore = setmetatable({}, SqlDatastore)
  -- Create the data directory if it doesn't exist.
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local conn = Connection.new(path)
  datastore.conn = conn
  return datastore
end

function SqlDatastore:init()
  if self.create_projects_table_stmt == nil then
    self.create_projects_table_stmt = PreparedStatement.new([[
      CREATE TABLE IF NOT EXISTS projects (
        name TEXT PRIMARY KEY,
        path TEXT NOT NULL UNIQUE,
        created INTEGER NOT NULL
      )
    ]], self.conn)
  end
  self.create_projects_table_stmt:exec_update()
  if self.create_file_keymaps_table_stmt == nil then
    self.create_file_keymaps_table_stmt = PreparedStatement.new([[
      CREATE TABLE IF NOT EXISTS file_keymaps (
        id INTEGER PRIMARY KEY,
        project TEXT NOT NULL,
        path TEXT NOT NULL,
        keymap TEXT NOT NULL,
        created INTEGER NOT NULL,
        UNIQUE (project, path),
        UNIQUE (project, keymap)
      )
    ]], self.conn)
  end
  self.create_file_keymaps_table_stmt:exec_update()
  if self.create_file_keymaps_project_idx_stmt == nil then
    self.create_file_keymaps_project_idx_stmt = PreparedStatement.new([[
      CREATE INDEX IF NOT EXISTS file_keymaps_project_idx ON file_keymaps (project);
    ]], self.conn)
  end
  self.create_file_keymaps_project_idx_stmt:exec_update()
end

---@alias hopper.Project {name: string, path: string}
---@alias hopper.FileMapping {id: integer, project: string, path: string, keymap: string}

---@return hopper.Project[]
function SqlDatastore:list_projects()
  if self.select_projects_stmt == nil then
    self.select_projects_stmt = PreparedStatement.new([[
      SELECT name, path FROM projects
    ]], self.conn)
  end
  local results = self.select_projects_stmt:exec_query()
  local projects = {} ---@type hopper.Project[]
  for _, result in ipairs(results) do
    table.insert(projects, {
      name = result[1],
      path = result[2],
    })
  end
  return projects
end

---@param path string
---@return hopper.Project | nil
function SqlDatastore:get_project_by_path(path)
  if self.select_project_by_path_stmt == nil then
    self.select_project_by_path_stmt = PreparedStatement.new([[
      SELECT name, path FROM projects WHERE path = ?
    ]], self.conn)
  end
  local results = self.select_project_by_path_stmt:exec_query({path})
  if #results < 1 then
    return nil
  end
  return {
    name = results[1][1],
    path = results[1][2],
  }
end

---@param name string
---@return hopper.Project | nil
function SqlDatastore:get_project_by_name(name)
  if self.select_project_by_name_stmt == nil then
    self.select_project_by_name_stmt = PreparedStatement.new([[
      SELECT name, path FROM projects WHERE name = ?
    ]], self.conn)
  end
  local results = self.select_project_by_name_stmt:exec_query({name})
  if #results < 1 then
    return nil
  end
  return {
    name = results[1][1],
    path = results[1][2],
  }
end

---@param name string
---@param path string
function SqlDatastore:set_project(name, path)
  if self.select_project_by_name_stmt == nil then
    self.select_project_by_name_stmt = PreparedStatement.new([[
      SELECT name, path FROM projects WHERE name = ?
    ]], self.conn)
  end
  local results = self.select_project_by_name_stmt:exec_query({name})
  if #results < 1 then
    if self.insert_project_stmt == nil then
      self.insert_project_stmt = PreparedStatement.new([[
        INSERT INTO projects (name, path, created) VALUES (?, ?, unixepoch())
      ]], self.conn)
    end
    self.insert_project_stmt:exec_update({name, path})
  else
    local existing_path = results[1][2]
    if path == existing_path then
      return
    end
    if self.update_project_stmt == nil then
      self.update_project_stmt = PreparedStatement.new([[
        UPDATE projects SET path = ? WHERE name = ?
      ]], self.conn)
    end
    self.update_project_stmt:exec_update({path, name})
  end
end

---@param name string
function SqlDatastore:remove_project(name)
  if self.delete_project_stmt == nil then
    self.delete_project_stmt = PreparedStatement.new([[
      DELETE FROM projects WHERE name = ?
    ]], self.conn)
  end
  self.delete_project_stmt:exec_update({name})
  if self.delete_files_for_project_stmt == nil then
    self.delete_files_for_project_stmt = PreparedStatement.new([[
      DELETE FROM file_keymaps WHERE project = ?
    ]], self.conn)
  end
  self.delete_files_for_project_stmt:exec_update({name})
end

---@param project? string Optionally filer by project.
---@param keymap_length? integer Optionally filter by keymap length.
---@return hopper.FileMapping[]
function SqlDatastore:list_file_keymaps(project, keymap_length)
  local results ---@type string[][]
  if project ~= nil and keymap_length ~= nil then
    if self.select_files_with_project_and_keymap_len_stmt == nil then
      self.select_files_with_project_and_keymap_len_stmt = PreparedStatement.new([[
        SELECT id, project, path, keymap FROM file_keymaps WHERE project = ? AND length(keymap) = ? ORDER BY created
      ]], self.conn)
    end
    results = self.select_files_with_project_and_keymap_len_stmt:exec_query({project, keymap_length})
  elseif project ~= nil then
    if self.select_files_with_project_stmt == nil then
      self.select_files_with_project_stmt = PreparedStatement.new([[
        SELECT id, project, path, keymap FROM file_keymaps WHERE project = ? ORDER BY created
      ]], self.conn)
    end
    results = self.select_files_with_project_stmt:exec_query({project})
  elseif keymap_length ~= nil then
    if self.select_files_with_keymap_len_stmt == nil then
      self.select_files_with_keymap_len_stmt = PreparedStatement.new([[
        SELECT id, project, path, keymap FROM file_keymaps WHERE length(keymap) = ? ORDER BY created
      ]], self.conn)
    end
    results = self.select_files_with_keymap_len_stmt:exec_query({keymap_length})
  else
    if self.select_files_stmt == nil then
      self.select_files_stmt = PreparedStatement.new([[
        SELECT id, project, path, keymap FROM file_keymaps ORDER BY created
      ]], self.conn)
    end
    results = self.select_files_stmt:exec_query()
  end
  local files = {} ---@type hopper.FileMapping[]
  for _, result in ipairs(results) do
    table.insert(files, {
      id = result[1],
      project = result[2],
      path = result[3],
      keymap = result[4],
    })
  end
  return files
end

---@param project string
---@return string[]
function SqlDatastore:list_keymaps(project)
  if self.select_keymaps_stmt == nil then
    self.select_keymaps_stmt = PreparedStatement.new([[
      SELECT keymap FROM file_keymaps WHERE project = ?
    ]], self.conn)
  end
  local results = self.select_keymaps_stmt:exec_query({project})
  local keymaps = {} ---@type string[]
  for _, result in ipairs(results) do
    table.insert(keymaps, result[1])
  end
  return keymaps
end

---@param project string
---@param keymap string
---@return hopper.FileMapping | nil
function SqlDatastore:get_file_keymap_by_keymap(project, keymap)
  if self.select_file_by_keymap_stmt == nil then
    self.select_file_by_keymap_stmt = PreparedStatement.new([[
      SELECT id, project, path, keymap FROM file_keymaps WHERE project = ? AND keymap = ?
    ]], self.conn)
  end
  local results = self.select_file_by_keymap_stmt:exec_query({project, keymap})
  if #results < 1 then
    return nil
  end
  return {
    id = results[1][1],
    project = results[1][2],
    path = results[1][3],
    keymap = results[1][4],
  }
end

---@param project string
---@param path string
---@return hopper.FileMapping | nil
function SqlDatastore:get_file_keymap_by_path(project, path)
  if self.select_file_by_path_stmt == nil then
    self.select_file_by_path_stmt = PreparedStatement.new([[
      SELECT id, project, path, keymap FROM file_keymaps WHERE project = ? AND path = ?
    ]], self.conn)
  end
  local results = self.select_file_by_path_stmt:exec_query({project, path})
  if #results < 1 then
    return nil
  end
  return {
    id = results[1][1],
    project = results[1][2],
    path = results[1][3],
    keymap = results[1][4],
  }
end

---@param project string
---@param path string
---@param keymap string
function SqlDatastore:set_file_keymap(project, path, keymap)
  if self.select_file_id_by_path_stmt == nil then
    self.select_file_id_by_path_stmt = PreparedStatement.new([[
      SELECT id FROM file_keymaps WHERE project = ? AND path = ?
    ]], self.conn)
  end
  local results = self.select_file_id_by_path_stmt:exec_query({project, path})
  if #results < 1 then
    if self.insert_file_stmt == nil then
      self.insert_file_stmt = PreparedStatement.new([[
        INSERT INTO file_keymaps (project, path, keymap, created)
        VALUES (?, ?, ?, unixepoch())
      ]], self.conn)
    end
    self.insert_file_stmt:exec_update({project, path, keymap})
  else
    if self.update_file_stmt == nil then
      self.update_file_stmt = PreparedStatement.new([[
        UPDATE file_keymaps SET keymap = ? WHERE id = ?
      ]], self.conn)
    end
    self.update_file_stmt:exec_update({keymap, results[1][1]})
  end
end

---@param project string
---@param path string
function SqlDatastore:remove_file_keymap(project, path)
  if self.delete_file_stmt == nil then
    self.delete_file_stmt = PreparedStatement.new([[
      DELETE FROM file_keymaps WHERE project = ? AND path = ?
    ]], self.conn)
  end
  self.delete_file_stmt:exec_update({project, path})
end

return M
