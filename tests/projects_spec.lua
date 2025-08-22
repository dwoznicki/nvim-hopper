local projects = require("hopper.projects")

describe("projects", function()
  describe("path_from_project_root", function()
    it("should handle absolute path to file without trailing slash", function()
      assert.equal(
        "src/components/Component.jsx",
        projects.path_from_project_root("/tests/fixtures/npm", "/tests/fixtures/npm/src/components/Component.jsx")
      )
    end)
    it("should handle absolute path to file with trailing slash", function()
      assert.equal(
        "src/components/Component.jsx",
        projects.path_from_project_root("/tests/fixtures/npm/", "/tests/fixtures/npm/src/components/Component.jsx")
      )
    end)
    it("should handle relative project path", function()
      assert.equal(
        "src/components/Component.jsx",
        projects.path_from_project_root("tests/fixtures/npm/", "tests/fixtures/npm/src/components/Component.jsx")
      )
    end)
    it("should handle root project path", function()
      assert.equal(
        "src/components/Component.jsx",
        projects.path_from_project_root("/", "/src/components/Component.jsx")
      )
    end)
    it("should handle paths in a different directory", function()
      assert.equal(
        "../fixtures/npm/src/components/Component.jsx",
        projects.path_from_project_root("/tests/dir/", "/tests/fixtures/npm/src/components/Component.jsx")
      )
    end)
  end)

  describe("path_from_cwd", function()
    it("should return path from CWD for simple cases", function()
      local cwd = vim.uv.cwd()
      assert.equal(
        "src/mod.lua",
        projects.path_from_cwd(cwd, "src/mod.lua")
      )
    end)
    it("should return path from CWD when project path doesn't match CWD", function()
      local cwd = vim.uv.cwd()
      assert.equal(
        "abc/123/src/mod.lua",
        projects.path_from_cwd(cwd .. "/abc/123", "src/mod.lua")
      )
    end)
    it("should resolve relative paths", function()
      local cwd = vim.uv.cwd()
      assert.equal(
        "src/mod.lua",
        projects.path_from_cwd(cwd .. "/abc/123", "../../src/mod.lua")
      )
    end)
    it("should return absolute path when CWD doesn't path file path at all", function()
      -- NOTE: This test will fail if this project path somehow actually exists. But that'll never
      -- happen, right?
      assert.equal(
        "/home/󰤇 /proj/src/mod.lua",
        projects.path_from_cwd("/home/󰤇 /proj", "src/mod.lua")
      )
    end)
  end)
end)
