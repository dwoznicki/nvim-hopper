local ffi = require("ffi")

ffi.cdef([[
  typedef struct sqlite3 sqlite3;
  typedef struct sqlite3_stmt sqlite3_stmt;

  int sqlite3_open(const char *filename, sqlite3 **ppDb);
  int sqlite3_close(sqlite3*);
  int sqlite3_exec(sqlite3*, const char *sql, int (*callback)(void*, int, char**, char**), void*, char **errmsg);
  int sqlite3_prepare_v2(sqlite3*, const char *zSql, int nByte, sqlite3_stmt **ppStmt, const char **pzTail);
  int sqlite3_reset(sqlite3_stmt*);
  int sqlite3_step(sqlite3_stmt*);
  int sqlite3_finalize(sqlite3_stmt*);
  int sqlite3_bind_text(sqlite3_stmt*, int, const char*, int n, void(*)(void*));
  int sqlite3_bind_int64(sqlite3_stmt*, int, long long);
  const unsigned char *sqlite3_column_text(sqlite3_stmt*, int);
  long long sqlite3_column_int64(sqlite3_stmt*, int);
  int sqlite3_column_count(sqlite3_stmt*);
  int sqlite3_changes(sqlite3*);
]])

local function sqlite3_lib()
  -- local opts = Snacks.picker.config.get()
  -- if opts.db.sqlite3_path then
  --   return opts.db.sqlite3_path
  -- end
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
    return sqlite.sqlite3_bind_text(stmt, idx, value, #value, nil)
  elseif value_type == "number" then
    return sqlite.sqlite3_bind_int64(stmt, idx, value)
  elseif value_type == "boolean" then
    return sqlite.sqlite3_bind_int64(stmt, idx, value and 1 or 0)
  else
    error("Unsupported value type: " .. type(value) .. " (" .. tostring(value) .. ")")
  end
end

local M = {}

M.DEFAULT_DB_PATH = "/tmp/hopper.db"

---@class hopper.Connection
---@field sqlite_conn ffi.cdata*
local Connection = {}
Connection.__index = Connection

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

M.Connection = Connection

---@class hopper.PreparedStatement
---@field sql string
---@field conn hopper.Connection
---@field sqlite_stmt ffi.cdata*
local PreparedStatement = {}
PreparedStatement.__index = PreparedStatement

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
    error("Failed to prepare statement: " .. code)
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
  if binds then
    for i, value in ipairs(binds) do
      local code = bind(stmt_ptr, i, value)
      if code ~= 0 then
        sqlite.sqlite3_finalize(stmt_ptr)
        error("Failed to bind parameter " .. i .. ": " .. tostring(value))
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
      sqlite.sqlite3_finalize(stmt_ptr)
      error("Error during sqlite3_step: " .. code)
    end
  end

  sqlite.sqlite3_finalize(stmt_ptr)
  return results
end

---@param binds? any[]
---@return integer
function PreparedStatement:exec_update(binds)
  local stmt_ptr = self.sqlite_stmt[0]
  if binds then
    for i, value in ipairs(binds) do
      local ret = bind(stmt_ptr, i, value)
      if ret ~= 0 then
        sqlite.sqlite3_finalize(stmt_ptr)
        error("Failed to bind parameter " .. i .. ": " .. tostring(value))
      end
    end
  end

  local code = sqlite.sqlite3_step(stmt_ptr)
  if code ~= 101 then  -- SQLITE_DONE
    sqlite.sqlite3_finalize(stmt_ptr)
    error("Error executing statement: " .. code)
  end

  sqlite.sqlite3_finalize(stmt_ptr)

  -- sqlite3_changes returns the number of rows affected by the last operation.
  return sqlite.sqlite3_changes(self.conn.sqlite_conn[0])
end

function PreparedStatement:close()
  local stmt_ptr = self.sqlite_stmt[0]
  if stmt_ptr then
    sqlite.sqlite3_close(stmt_ptr)
    self.sqlite_stmt = nil
  end
end


M.PreparedStatement = PreparedStatement

---@class hopper.SqlDatastore
---@field conn hopper.Connection
---@field create_tables_stmt hopper.PreparedStatement | nil
---@field select_qfiles_stmt hopper.PreparedStatement | nil
---@field select_qfile_id_by_path_stmt hopper.PreparedStatement | nil
---@field insert_qfile_stmt hopper.PreparedStatement | nil
---@field update_qfile_stmt hopper.PreparedStatement | nil
---@field delete_qfile_stmt hopper.PreparedStatement | nil
---@field update_usage_stmt hopper.PreparedStatement | nil
local SqlDatastore = {}
SqlDatastore.__index = SqlDatastore

---@param path string
function SqlDatastore.new(path)
  local datastore = setmetatable({}, SqlDatastore)
  local conn = Connection.new(path)
  datastore.conn = conn
  return datastore
end

function SqlDatastore:init()
  if self.create_tables_stmt == nil then
    self.create_tables_stmt = PreparedStatement.new([[
      CREATE TABLE IF NOT EXISTS quick_files (
        id INTEGER PRIMARY KEY,
        project TEXT NOT NULL,
        path TEXT NOT NULL,
        keymap TEXT NOT NULL,
        key_indexes_json TEXT NOT NULL CHECK (json_validate(key_indexes)),
        created INTEGER NOT NULL,
        UNIQUE (project, path),
        UNIQUE (project, keymap)
      );
      CREATE INDEX quick_files_project_idx ON quick_files (project);
    ]], self.conn)
  end
  self.create_tables_stmt:exec_update()
end

---@param project string
---@return string[][]
function SqlDatastore:get_quick_files(project)
  if self.select_qfiles_stmt == nil then
    self.select_qfiles_stmt = PreparedStatement.new([[
      SELECT path, keymap, key_indexes_json FROM quick_files WHERE project = ? ORDER BY last_used DESC
    ]], self.conn)
  end
  local results = self.select_qfiles_stmt:exec_query({project})
  return results
end

---@param project string
---@param path string
---@param keymap string
---@param is_edited boolean
function SqlDatastore:set_quick_file(project, path, keymap, is_edited)
  if self.select_qfile_id_by_path_stmt == nil then
    self.select_qfile_id_by_path_stmt = PreparedStatement.new([[
      SELECT id FROM quick_files WHERE project = ? AND path = ?
    ]], self.conn)
  end
  local results = self.select_qfile_id_by_path_stmt:exec_query({project, path})
  if #results > 0 then
    if self.insert_qfile_stmt == nil then
      self.insert_qfile_stmt = PreparedStatement.new([[
        INSERT INTO quick_files (project, path, keymap, is_edited, created, last_used)
        VALUES (?, ?, ?, ?, unixepoch(), unixepoch())
      ]], self.conn)
    end
    self.insert_qfile_stmt:exec_update({project, path, keymap, is_edited})
  else
    if self.update_qfile_stmt == nil then
      self.update_qfile_stmt = PreparedStatement.new([[
        UPDATE quick_files SET keymap = ?, is_edited = ? WHERE id = ?
      ]], self.conn)
    end
    self.update_qfile_stmt:exec_update({keymap, is_edited, results[0][0]})
  end
end

---@param project string
---@param path string
function SqlDatastore:remove_quick_file(project, path)
  if self.delete_qfile_stmt == nil then
    self.delete_qfile_stmt = PreparedStatement.new([[
      DELETE FROM quick_files WHERE project = ? AND path = ?
    ]], self.conn)
  end
  self.delete_qfile_stmt:exec_update({project, path})
end

---@param project string
---@param keymap string
function SqlDatastore:track_quick_file_usage(project, keymap)
  if self.update_usage_stmt == nil then
    self.update_usage_stmt = PreparedStatement.new([[
      UPDATE quick_files SET last_used = unixepoch() WHERE project = ? AND keymap = ?
    ]], self.conn)
  end
  self.update_usage_stmt:exec_update({project, keymap})
end

M.SqlDatastore = SqlDatastore

return M
