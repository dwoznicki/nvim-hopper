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

---@return hopper.Project[] possible_projects
function M.list_projects_from_cwd()
  local datastore = require("hopper.db").datastore()
  local possible_projects = {} ---@type hopper.Project[]
  local paths = {loop.cwd()}
  for dir in vim.fs.parents(loop.cwd()) do
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
      local name = datastore:get_project_by_path(path)
      if name ~= nil then
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

---@param project string | hopper.Project
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

---@param forced_current_project string | hopper.Project | nil
---@return hopper.Project
function M.current_project(forced_current_project)
  if forced_current_project ~= nil then
    return M.resolve_project(forced_current_project)
  end
  if _curr_project == nil then
    local projects = M.list_projects_from_cwd()
    _curr_project = projects[#projects]
  end
  return _curr_project
end

return M
