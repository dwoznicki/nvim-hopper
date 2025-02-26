local M = {}

local root_markers = {
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

---@param dir string
---@return boolean is_root true if this dir looks like the root of a project
local function is_project_root(dir)
  for _, marker in ipairs(root_markers) do
    if vim.fn.filereadable(vim.fn.expand(dir .. "/" .. marker)) == 1 or
      vim.fn.isdirectory(vim.fn.expand(dir .. "/" .. marker)) == 1 then
        return true
      end
  end
  return false
end

---@param starting_dir string
---@return string | nil project_root
local function find_project_root(starting_dir)
  local dir = starting_dir
  while dir ~= "/" do
    if is_project_root(dir) then
      return dir
    end
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  return nil
end

---@param file_path string
---@return string absolute_path
local function to_absoluate_path(file_path)
  if string.sub(file_path, 1, 1) == "/" then
    -- Path already appears to be absolute.
    return vim.uv.fs_realpath(file_path) or file_path
  else
    local abs_path = vim.uv.cwd() .. "/" .. file_path
    return vim.uv.fs_realpath(abs_path) or abs_path
  end
end

---@param file_path string
---@return string path_from_project_root
function M.get_path_from_project_root(file_path)
  local abs_path = to_absoluate_path(file_path)
  local file_dir = vim.fn.fnamemodify(abs_path, ":h")
  local project_root = find_project_root(file_dir)
  if project_root then
    return string.sub(abs_path, string.len(project_root) + 2)
  else
    return abs_path
  end
end

return M
