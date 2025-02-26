local filepath = require("bufhopper.filepath")

describe("filepath utilities", function()
  describe("getting path from project root", function()
    it("should handle relative path to file", function()
      assert.equal(
        "src/components/Component.jsx",
        filepath.get_path_from_project_root("tests/fixtures/npm/src/components/Component.jsx")
      )
    end)
    it("should handle relative path to dir", function()
      assert.equal(
        "src/components",
        filepath.get_path_from_project_root("tests/fixtures/npm/src/components/")
      )
    end)
    it("should handle absolute path to file", function()
      assert.equal(
        "src/components/Component.jsx",
        filepath.get_path_from_project_root(vim.uv.cwd() .. "/tests/fixtures/npm/src/components/Component.jsx")
      )
    end)
    it("should handle absolute path to dir", function()
      assert.equal(
        "src/components",
        filepath.get_path_from_project_root(vim.uv.cwd() .. "/tests/fixtures/npm/src/components/")
      )
    end)
  end)
end)
