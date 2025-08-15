local loop = vim.uv or vim.loop

local M = {}

---@type hopper.Project
local DEFAULT_PROJECT = {name = "root", path = "/"}

local ROOT_MARKERS = {
  ".git",
  "Makefile",
  "package.json",
  ".hg",
  ".bzr",
  "pom.xml",
  "build.gradle",
  "Cargo.toml",
  "go.mod",
  "requirements.txt",
  "setup.py",
  "CMakeLists.txt",
  "pyproject.toml",
  ".svn",
  ".gitignore",
  "Pipfile",
  "Gemfile",
  "mix.exs",
  "deps.edn",
  "project.clj",
  "shadow-cljs.edn",
  "build.boot",
  "info.rkt",
  "spago.dhall",
}

local _curr_project = nil ---@type hopper.Project | nil

---@param base_path string
---@return hopper.Project[] possible_projects
function M.list_projects_from_path(base_path)
  local datastore = require("hopper.db").datastore()
  local possible_projects = {} ---@type hopper.Project[]
  local paths = {base_path}
  for dir in vim.fs.parents(base_path) do
    table.insert(paths, dir)
  end
  for _, path in ipairs(paths) do
    local is_root = false
    for _, marker in ipairs(ROOT_MARKERS) do
      if loop.fs_stat(path .. "/" .. marker) ~= nil then
        is_root = true
        break
      end
    end
    if is_root then
      local project = datastore:get_project_by_path(path)
      local name ---@type string
      if project ~= nil then
        name = project.name
      else
        name = vim.fs.basename(path)
      end
      table.insert(possible_projects, {
        name = name,
        path = path,
      })
    end
  end
  table.insert(possible_projects, DEFAULT_PROJECT)
  return possible_projects
end

---@param project hopper.Project | string
---@return hopper.Project
function M.resolve_project(project)
  if type(project) == "table" then
    return project
  end
  local datastore = require("hopper.db").datastore()
  local project_from_name = datastore:get_project_by_name(project)
  if project_from_name ~= nil then
    return project_from_name
  end
  if loop.fs_stat(project) == nil then
    error(string.format("Unable to resolve project: %s", project))
  end
  local project_from_path = datastore:get_project_by_path(project)
  if project_from_path ~= nil then
    return project_from_path
  end
  local name = vim.fs.basename(project)
  datastore:set_project(name, project)
  return {
    name = name,
    path = project,
  }
end

---@param project hopper.Project
function M.set_current_project(project)
  local datastore = require("hopper.db").datastore()
  datastore:set_project(project.name, project.path)
  _curr_project = project
end

---@return hopper.Project
function M.current_project()
  if _curr_project == nil then
    local base_path = vim.api.nvim_buf_get_name(0)
    if not base_path then
      base_path = loop.cwd()
    end
    local projects = M.list_projects_from_path(base_path)
    _curr_project = projects[1]
    local datastore = require("hopper.db").datastore()
    datastore:set_project(_curr_project.name, _curr_project.path)
  end
  return _curr_project
end

---@param project_path string
---@param file_path string
---@return string path_from_project_root
function M.path_from_project_root(project_path, file_path)
  if not vim.startswith(file_path, project_path) then
    error(string.format("File %s is not part of the current project %s.", file_path, project_path))
  end
  local start_idx = string.len(project_path) + 1
  local relative_path = string.sub(file_path, start_idx)
  if vim.startswith(relative_path, "/") then
    relative_path = string.sub(relative_path, 2)
  end
  return relative_path
  -- if vim.endswith(project_path, "/") then
  --   -- Remove trailing "/" from path.
  --   start_idx = start_idx + 1
  -- end
  -- if string.len(project_path) > 1 then
  --   -- Remove separating "/", but only if it's not the same character as the leading "/".
  --   start_idx = start_idx + 1
  -- end
  -- return string.sub(file_path, start_idx)
end

---@param project hopper.Project | string | nil
---@return hopper.Project
function M.ensure_project(project)
  if project then
    return M.resolve_project(project)
  end
  return M.current_project()
end

return M
