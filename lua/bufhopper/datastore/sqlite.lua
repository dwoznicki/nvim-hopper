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

--@alias sqlite3* ffi.cdata*
--@alias sqlite3_stmt* ffi.cdata*

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

---@class hopper.SqlQuery
---@field sqlite_conn ffi.cdata*
---@field sqlite_stmt ffi.cdata*
local SqlQuery = {}
SqlQuery.__index = SqlQuery

---@param dbpath string
---@param sql string
function SqlQuery.new(dbpath, sql)
  local query = setmetatable({}, SqlQuery)
  -- Open a connection to the database.
  local sqlite_conn = ffi.new("sqlite3*[1]")
  local code = sqlite.sqlite3_open(dbpath, sqlite_conn)
  if code ~= 0 then
    error("Failed to open database: " .. dbpath)
  end
  query.sqlite_conn = sqlite_conn
  ffi.gc(sqlite_conn, function()
    query:close()
  end)
  -- Prepare a statement.
  local sqlite_stmt = ffi.new("sqlite3_stmt*[1]")
  code = sqlite.sqlite3_prepare_v2(sqlite_conn[0], sql, #sql, sqlite_stmt, nil)
  if code ~= 0 then
    error("Failed to prepare statement: " .. code)
  end
  query.sqlite_stmt = sqlite_stmt
  ffi.gc(sqlite_stmt, function()
    query:close()
  end)
  return query
end

---@param binds? any[]
---@return number
function SqlQuery:exec_update(binds)

  -- local conn_ptr = self.sqlite_conn[0]
  -- local stmt_ptr = ffi.new("sqlite3_stmt*[1]")
  -- local code = sqlite.sqlite3_prepare_v2(conn_ptr, query, #query, stmt_ptr, nil)
  -- if code ~= 0 then
  --   error("Failed to prepare statement: " .. code)
  -- end
  -- local stmt = stmt_ptr[0]

  -- Bind values if provided.
  if binds then
    for i, value in ipairs(binds) do
      local code = bind(self.sqlite_stmt[0], i, value)
      if code ~= 0 then
        sqlite.sqlite3_finalize(self.sqlite_stmt[0])
        error(string.format("Failed to bind parameter %d (%s)", i, tostring(value)))
      end
    end
  end

  local code = sqlite.sqlite3_step(self.sqlite_stmt[0])
  if code ~= 101 then  -- SQLITE_DONE
    sqlite.sqlite3_finalize(self.sqlite_stmt[0])
    error("Error executing statement: " .. code)
  end

  sqlite.sqlite3_finalize(self.sqlite_stmt[0])

  return sqlite.sqlite3_changes(self.sqlite_conn[0])
end

function SqlQuery:close()
  if self.sqlite_stmt[0] then
    sqlite.sqlite3_finalize(self.sqlite_stmt[0])
    self.sqlite_stmt = nil
  end
  if self.sqlite_conn[0] then
    sqlite.sqlite3_close(self.sqlite_conn[0])
    self.sqlite_conn = nil
  end
end

M.SqlQuery = SqlQuery

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

-- ---@param query string
-- function Connection:exec(query)
--   local conn_ptr = self.sqlite_conn[0]
--   local error_message = ffi.new("char*[1]")
--   local code = sqlite.sqlite3_exec(conn_ptr, query, nil, nil, error_message)
--   if code ~= 0 then
--     error(ffi.string(error_message[0]))
--   end
-- end

---@param query string
---@return table[]  -- array of rows; each row is an array of column values (as strings)
function Connection:exec_query(query)
  local conn_ptr = self.sqlite_conn[0]
  local stmt_ptr = ffi.new("sqlite3_stmt*[1]")
  local code = sqlite.sqlite3_prepare_v2(conn_ptr, query, #query, stmt_ptr, nil)
  if code ~= 0 then
    error("Failed to prepare statement: " .. code)
  end

  local stmt = stmt_ptr[0]
  local results = {}

  -- Get the number of columns in the result set.
  local col_count = sqlite.sqlite3_column_count(stmt)

  while true do
    code = sqlite.sqlite3_step(stmt)
    if code == 100 then  -- SQLITE_ROW
      local row = {}
      for i = 0, col_count - 1 do
        -- Retrieve column text. (You could add type checking if needed.)
        local col_text = sqlite.sqlite3_column_text(stmt, i)
        row[i+1] = col_text and ffi.string(col_text) or nil
      end
      table.insert(results, row)
    elseif code == 101 then  -- SQLITE_DONE
      break
    else
      sqlite.sqlite3_finalize(stmt)
      error("Error during sqlite3_step: " .. code)
    end
  end

  sqlite.sqlite3_finalize(stmt)
  return results
end

---@param query string  -- the SQL insert statement
---@param binds? any[]  -- optional array of values to bind
---@return number       -- the number of rows affected
function Connection:exec_update(query, binds)
  local conn_ptr = self.sqlite_conn[0]
  local stmt_ptr = ffi.new("sqlite3_stmt*[1]")
  local code = sqlite.sqlite3_prepare_v2(conn_ptr, query, #query, stmt_ptr, nil)
  if code ~= 0 then
    error("Failed to prepare statement: " .. code)
  end

  local stmt = stmt_ptr[0]

  -- Bind values if provided.
  if binds then
    for i, value in ipairs(binds) do
      local ret = bind(stmt, i, value)
      if ret ~= 0 then
        sqlite.sqlite3_finalize(stmt)
        error(string.format("Failed to bind parameter %d (%s)", i, tostring(value)))
      end
    end
  end

  code = sqlite.sqlite3_step(stmt)
  if code ~= 101 then  -- SQLITE_DONE == 101
    sqlite.sqlite3_finalize(stmt)
    error("Error executing statement: " .. code)
  end

  sqlite.sqlite3_finalize(stmt)

  -- sqlite3_changes returns the number of rows affected by the last operation.
  return sqlite.sqlite3_changes(conn_ptr)
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
---@field sqlite_stmt ffi.cdata*
local PreparedStatement = {}
PreparedStatement.__index = PreparedStatement

---@param conn hopper.Connection
---@param query string
function PreparedStatement.new(conn, query)
  local stmt = setmetatable({}, PreparedStatement)
  local sqlite_stmt = ffi.new("sqlite3_stmt*[1]")
  stmt.sqlite_stmt = sqlite_stmt
  local code = sqlite.sqlite3_prepare_v2(conn.sqlite_conn[0], query, #query, sqlite_stmt, nil)
  if code ~= 0 then
    error("Failed to prepare statement: " .. code)
  end
  ffi.gc(sqlite_stmt, function()
    stmt:close()
  end)
  return stmt
end

function PreparedStatement:close()
  if self.sqlite_stmt[0] then
    sqlite.sqlite3_finalize(self.sqlite_stmt[0])
    self.sqlite_stmt = nil
  end
end

---@param path string
function M.init(path)
  -- local handle = ffi.new("sqlite3*[1]")
  -- if sqlite.sqlite3_open(path, handle) ~= 0 then
  --   error("Failed to open database: " .. path)
  -- end
  local conn = Connection.new(path)
  conn:exec_update([[
    CREATE TABLE IF NOT EXISTS projects (
      id INTEGER PRIMARY KEY,
      path TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS keymaps (
      project_id INTEGER NOT NULL,
      keys TEXT NOT NULL,
      path TEXT NOT NULL,
      FOREIGN KEY (project_id) REFERENCES projects (id)
    );
  ]])
  conn:close()
end

return M
