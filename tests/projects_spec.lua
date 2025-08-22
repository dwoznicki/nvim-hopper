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
end)
