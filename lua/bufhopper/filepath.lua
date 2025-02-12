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
---@return string
function M.get_path_from_project_root(file_path)
  local abs_path = vim.fn.expand(file_path)
  local file_dir = vim.fn.fnamemodify(abs_path, ":h")
  local project_root = find_project_root(file_dir)
  if project_root then
    return vim.fn.fnamemodify(abs_path, ":." .. project_root)
  else
    return abs_path
  end
end

return M
