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
    it("should fail when project path doesn't match file path", function()
      local success, result = pcall(projects.path_from_project_root, "/some/dir/", "/tests/fixtures/npm/src/components/Component.jsx")
      assert.is_false(success)
      assert.is_true(string.find(result, "is not part of the current project") ~= nil)
    end)
  end)
end)
