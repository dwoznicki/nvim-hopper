local quickfile = require("hopper.quickfile")

describe("quickfile utilities", function()
  describe("truncate_path", function()
    it("should truncate path to available width (20 chars)", function()
      assert.equal(
        "this/…/Component.jsx",
        quickfile.truncate_path("this/is/a/long/path/to/some/nested/Component.jsx", 20)
      )
    end)
    it("should truncate path to available width (30 chars)", function()
      assert.equal(
        "this/…/to/some/nested/Component.jsx",
        quickfile.truncate_path("this/is/a/long/path/to/some/nested/Component.jsx", 30)
      )
    end)
    it("should truncate path to available width (40 chars)", function()
      assert.equal(
        "this/…/long/path/to/some/nested/Component.jsx",
        quickfile.truncate_path("this/is/a/long/path/to/some/nested/Component.jsx", 40)
      )
    end)
    it("should handle long file names", function()
      assert.equal(
        "ThisIsALongFileName.tsx",
        quickfile.truncate_path("ThisIsALongFileName.tsx", 10)
      )
    end)
    it("should truncate base dir if too long", function()
      assert.equal(
        "…/SomeFileName.tsx",
        quickfile.truncate_path("some-long-winded-dir-name/SomeFileName.tsx", 20)
      )
    end)
    it("should properly truncate absolute paths #only", function()
      assert.equal(
        "/user/…/dummy/absolute/path.py",
        quickfile.truncate_path("/user/somebody/dummy/absolute/path.py", 30)
      )
    end)
  end)

  describe("keymap_location_in_path", function()
    it("should pick correct indexes (filename only)", function()
      assert.same(
        {1, 2},
        quickfile.keymap_location_in_path("file.txt", "fi")
      )
    end)
    it("should pick correct indexes (with path)", function()
      local path = "path/to/some/"
      assert.same(
        {string.len(path) + 1, string.len(path) + 2},
        quickfile.keymap_location_in_path(path .. "file.txt", "fi")
      )
    end)
    it("should pick correct indexes (split in filename)", function()
      local path = "path/to/some/"
      assert.same(
        {string.len(path) + 1, string.len(path) + 6},
        quickfile.keymap_location_in_path(path .. "file.txt", "ft")
      )
    end)
    it("should pick first index when multiple chars are available", function()
      assert.same(
        {1, 2},
        quickfile.keymap_location_in_path("gooooooooooogle", "go")
      )
    end)
    it("should handle one character in keymap", function()
      assert.same(
        {2},
        quickfile.keymap_location_in_path("file.txt", "i")
      )
    end)
    it("should handle empty keymap", function()
      assert.same(
        {},
        quickfile.keymap_location_in_path("file.txt", "")
      )
    end)
    it("should prefer tokens later in path", function()
      assert.same(
        {13, 9},
        quickfile.keymap_location_in_path("abc/abc/abc/d.sql", "da")
      )
    end)
    it("should allow keymap order to differ from path character order", function()
      assert.same(
        {4, 1},
        quickfile.keymap_location_in_path("elif.txt", "fe")
      )
    end)
    it("should allow keymaps with repeat keys", function()
      assert.same(
        {1, 4},
        quickfile.keymap_location_in_path("fluffyboy.txt", "ff")
      )
    end)
    it("should allow keymaps with repeat keys", function()
      assert.same(
        {1, 4},
        quickfile.keymap_location_in_path("fluffyboy.txt", "ff")
      )
    end)
    it("should handle missing locations (default -1 behavior)", function()
      assert.same(
        {-1, -1},
        quickfile.keymap_location_in_path("q", "ab")
      )
    end)
    it("should handle missing locations (explicit -1 behavior)", function()
      assert.same(
        {-1},
        quickfile.keymap_location_in_path("q", "a", {missing_behavior = "-1"})
      )
    end)
    it("should handle missing locations (end behavior)", function()
      -- For "end", we expect the location to be after the last path indexes.
      assert.same(
        {5, 6},
        quickfile.keymap_location_in_path("file", "ab", {missing_behavior = "end"})
      )
    end)
    it("should handle missing locations (end behavior, one present in path)", function()
      assert.same(
        {5, 2},
        quickfile.keymap_location_in_path("file", "ai", {missing_behavior = "end"})
      )
    end)
    it("should handle missing locations (nearby behavior)", function()
      -- For "nearby" behavior, we should choose the next index after the previously found index
      -- when we cannot find a valid location.
      assert.same(
        {1, 2},
        quickfile.keymap_location_in_path("file", "fq", {missing_behavior = "nearby"})
      )
    end)
    it("should handle missing locations (nearby but no initial location found)", function()
      -- For "nearby" behavior, we'll just use the same indexes as "end" when we can't find an
      -- initial location index to anchor off of.
      assert.same(
        {5, 6},
        quickfile.keymap_location_in_path("file", "qq", {missing_behavior = "nearby"})
      )
    end)
  end)
end)
