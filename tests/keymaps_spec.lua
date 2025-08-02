local keymaps = require("hopper.keymaps")
local utils = require("hopper.utils")

describe("keymaps", function()
  describe("#truncate_path", function()
    it("should truncate path to available width (20 chars)", function()
      assert.equal(
        "this/…/Component.jsx",
        keymaps.truncate_path("this/is/a/long/path/to/some/nested/Component.jsx", 20)
      )
    end)
    it("should truncate path to available width (30 chars)", function()
      assert.equal(
        "this/…/to/some/nested/Component.jsx",
        keymaps.truncate_path("this/is/a/long/path/to/some/nested/Component.jsx", 30)
      )
    end)
    it("should truncate path to available width (40 chars)", function()
      assert.equal(
        "this/…/long/path/to/some/nested/Component.jsx",
        keymaps.truncate_path("this/is/a/long/path/to/some/nested/Component.jsx", 40)
      )
    end)
    it("should handle long file names", function()
      assert.equal(
        "ThisIsALongFileName.tsx",
        keymaps.truncate_path("ThisIsALongFileName.tsx", 10)
      )
    end)
    it("should truncate base dir if too long", function()
      assert.equal(
        "…/SomeFileName.tsx",
        keymaps.truncate_path("some-long-winded-dir-name/SomeFileName.tsx", 20)
      )
    end)
    it("should properly truncate absolute paths", function()
      assert.equal(
        "/user/…/dummy/absolute/path.py",
        keymaps.truncate_path("/user/somebody/dummy/absolute/path.py", 30)
      )
    end)
  end)

  describe("#keymap_location_in_path", function()
    it("should pick correct indexes (just filename)", function()
      assert.same(
        {1, 2},
        keymaps.keymap_location_in_path("file.txt", "fi")
      )
    end)
    it("should pick correct indexes (with path)", function()
      local path = "path/to/some/"
      assert.same(
        {string.len(path) + 1, string.len(path) + 2},
        keymaps.keymap_location_in_path(path .. "file.txt", "fi")
      )
    end)
    it("should pick correct indexes (split in filename)", function()
      local path = "path/to/some/"
      assert.same(
        {string.len(path) + 1, string.len(path) + 6},
        keymaps.keymap_location_in_path(path .. "file.txt", "ft")
      )
    end)
    it("should pick first index when multiple chars are available", function()
      assert.same(
        {1, 2},
        keymaps.keymap_location_in_path("gooooooooooogle", "go")
      )
    end)
    it("should handle one character in keymap", function()
      assert.same(
        {2},
        keymaps.keymap_location_in_path("file.txt", "i")
      )
    end)
    it("should handle empty keymap", function()
      assert.same(
        {},
        keymaps.keymap_location_in_path("file.txt", "")
      )
    end)
    it("should prefer tokens later in path", function()
      assert.same(
        {13, 9},
        keymaps.keymap_location_in_path("abc/abc/abc/d.sql", "da")
      )
    end)
    it("should allow keymap order to differ from path character order", function()
      assert.same(
        {4, 1},
        keymaps.keymap_location_in_path("elif.txt", "fe")
      )
    end)
    it("should allow keymaps with repeat keys", function()
      assert.same(
        {1, 4},
        keymaps.keymap_location_in_path("fluffyboy.txt", "ff")
      )
    end)
    it("should allow keymaps with repeat keys", function()
      assert.same(
        {1, 4},
        keymaps.keymap_location_in_path("fluffyboy.txt", "ff")
      )
    end)
    it("should handle missing locations (default -1 behavior)", function()
      assert.same(
        {-1, -1},
        keymaps.keymap_location_in_path("q", "ab")
      )
    end)
    it("should handle missing locations (explicit -1 behavior)", function()
      assert.same(
        {-1},
        keymaps.keymap_location_in_path("q", "a", {missing_behavior = "-1"})
      )
    end)
    it("should handle missing locations (end behavior)", function()
      -- For "end", we expect the location to be after the last path indexes.
      assert.same(
        {5, 6},
        keymaps.keymap_location_in_path("file", "ab", {missing_behavior = "end"})
      )
    end)
    it("should handle missing locations (end behavior, one present in path)", function()
      assert.same(
        {5, 2},
        keymaps.keymap_location_in_path("file", "ai", {missing_behavior = "end"})
      )
    end)
    it("should handle missing locations (nearby behavior)", function()
      -- For "nearby" behavior, we should choose the next index after the previously found index
      -- when we cannot find a valid location.
      assert.same(
        {1, 2},
        keymaps.keymap_location_in_path("file", "fq", {missing_behavior = "nearby"})
      )
    end)
    it("should handle missing locations (nearby but no initial location found)", function()
      -- For "nearby" behavior, we'll just use the same indexes as "end" when we can't find an
      -- initial location index to anchor off of.
      assert.same(
        {5, 6},
        keymaps.keymap_location_in_path("file", "qq", {missing_behavior = "nearby"})
      )
    end)
  end)
  describe("#keymap_for_path", function()
    it("should find simple keymap from path", function()
      assert.same(
        "wo",
        keymaps.keymap_for_path(
          "/hello/world.txt",
          2,
          2,
          utils.set(keymaps.keysets.alphanumeric),
          {}
        )
      )
    end)
    it("should skip existing keymaps and find next best", function()
      assert.same(
        "wl",
        keymaps.keymap_for_path(
          "/hello/world.txt",
          2,
          2,
          utils.set(keymaps.keysets.alphanumeric),
          utils.set({"wo", "wr"})
        )
      )
    end)
    it("should circle back around to use earlier characters in path token when necessary", function()
      assert.same(
        "ow",
        keymaps.keymap_for_path(
          "/h/wor",
          2,
          2,
          utils.set(keymaps.keysets.alphanumeric),
          utils.set({"wo", "wr", "wh", "or"})
        )
      )
    end)
    it("should use characters from earlier path tokens when necessary", function()
      assert.same(
        "he",
        keymaps.keymap_for_path(
          "/hel/wo",
          2,
          2,
          utils.set(keymaps.keysets.alphanumeric),
          utils.set({"wo", "wh", "we", "wl", "ow", "oh", "oe", "ol"})
        )
      )
    end)
    it("should repsect allowed keys", function()
      assert.same(
        "wl",
        keymaps.keymap_for_path(
          "/hello/world",
          2,
          2,
          utils.set({"w", "r", "l"}),
          utils.set({"wr"})
        )
      )
    end)
    it("should allow for 1 character long keymaps", function()
      assert.same(
        "r",
        keymaps.keymap_for_path(
          "/hello/world",
          2,
          1,
          utils.set(keymaps.keysets.alphanumeric),
          utils.set({"w", "o"})
        )
      )
    end)
    it("should allow for 3 character long keymaps", function()
      assert.same(
        "wor",
        keymaps.keymap_for_path(
          "/hello/world",
          2,
          3,
          utils.set(keymaps.keysets.alphanumeric),
          utils.set({})
        )
      )
    end)
    it("should allow repeated characters", function()
      assert.same(
        "ww",
        keymaps.keymap_for_path(
          "/wow",
          2,
          2,
          utils.set(keymaps.keysets.alphanumeric),
          utils.set({"wo"})
        )
      )
    end)
    it("should randomly pick characters to finish keymap", function()
      assert.same(
        "wa",
        keymaps.keymap_for_path(
          "/world",
          2,
          2,
          utils.set({"a", "w", "o", "r", "l", "d"}),
          utils.set({"wo", "wr", "wl", "wd", "ww", "or", "ol", "od", "ow", "rl", "rd", "rw", "ro", "ld", "lw", "lo", "lr", "dw", "do", "dr", "dl"})
        )
      )
    end)
    it("should just pick something at random when no valid keymaps found #only", function()
      assert.is_not_nil(
        keymaps.keymap_for_path(
          "/wo",
          2,
          2,
          utils.set(keymaps.keysets.alphanumeric),
          utils.set({"wo", "ow", "ww", "oo"})
        )
      )
    end)
  end)
end)
