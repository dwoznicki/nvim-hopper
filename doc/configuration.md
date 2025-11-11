# Configuration

nvim-hopper can be configured by passing in a table to the `setup` function.

```lua
require("hopper").setup({
  -- Your config goes here.
})
```

All options are optional. Missing values will be replaced with the default at setup time.

## Default options

These are the default setup options.

```lua
{
  keymapping = {
    -- Available keys for keymaps alphanumeric.
    keyset = "abcdefghijklmnopqrstuvwxyz1234567890",
    -- All keymaps must be exactly 2 characters long.
    length = 2,
    -- When a file is selected, use this command to open it by default. Equivalent to `:edit $FILE`.
    default_open_cmd = "edit",
  },
  db = {
    -- Path to find sqlite3 binary. Expect to find the binary in the $PATH on Mac/Linux, or path to
    -- Vim cached `sqlite.dll` on Windows.
    sqlite_path = "sqlite3",
    -- Path to sqlite3 database file. Probably `~/.local/share/nvim/hopper/hopper.db`.
    database_path = require("hopper.db.sqlite").DEFAULT_DB_PATH,
  },
  float = {
    -- Floating window width/height. A number between 0 and 1 is treated as a percentage of
    -- available space. A number greater than 1 is treated as an exact character size.
    width = 0.6, -- 60% of available width
    height = 0.6, -- 60% of available height
  },
  -- Colors are determined at setup time. They are mostly based on the values the current
  -- colorscheme applies to common highlight names.
  colors = {
    project = nil, -- "Statement"
    action = nil, -- "Function"
    first_key = nil, -- "Exception"
    second_key = nil, -- "Special"
    third_key = nil, -- "Identifier"
    fourth_key = nil, -- "String"
  },
  actions = {
    display = {
      -- Display for special keys, which Vim typically represents in format `<KEY>`.
      -- There are some sensible defaults which require a nerdfont to display properly.
      special_keys = {
        ["<cr>"] = "󰌑 ",
        ["<tab>"] = "󰌒 ",
        ["<bs>"] = "󰁮 ",
        ["<esc>"] = "󱊷 ",
      },
    },
    -- Change the keymaps that perform standard actions in different views.
    hopper = {
      -- Switch to keymapper float, assigning to current file.
      open_keymapper = {"m"},
      -- Switch to picker, if configured.
      open_picker = {";"},
      -- Switch to project control menu.
      open_project_menu = {"p"},
      -- Close hopper float.
      close = {"q"},
    },
    keymapper = {
      -- Confirm new keymap for file.
      confirm = {"<cr>"},
      -- Autocomplete suggested keymap.
      accept_suggestion = {"<tab>"},
      -- Return to previous float view, if one is available.
      go_back = {"<bs>"},
      -- Close keymapper float.
      close = {"q"},
    },
    new_project = {
      -- Confirm new project.
      confirm = {"<cr>"},
      -- Autocomplete suggested project name/path.
      accept_suggestion = {"<tab>"},
      -- Close new project float.
      close = {"q"},
    },
  },
}
```

## Full configuration

### `keymapping.keyset`

`string[]` or `string`

A list of allowed characters for new keymappings. You can currently create mappings using other characters, but suggested mappings will be limited to this set. If a string is provided, it will be split into a list of single character strings.

### `keymapping.length`

`integer`

The length for all valid keymappings. Any stored keymappings with a different length will be ignored during file selection. This is a limitation to enforce consistency, and to avoid dealing with keypress timeouts (e.g. if I have file A mapped to "ab" and file B mapped to "abc", I have to wait for a timeout after typing in "ab" before opening file A).

This limitation may be removed in the future, at which point the keymapping length would become fully optional.

### `keymapping.default_open_cmd`

`string`

The command used to open a file. It is executed as `vim.cmd(default_open_cmd, file_path)`.

### `db.sqlite_path`

`string`

Path to the sqlite3 executable. By default, nvim-hopper expects to find `sqlite3` on the $PATH, which should be fine for most installations.

### `db.database_path`

`string`

Path to the sqlite3 database file. By default, nvim-hopper places this as a `hopper.db` file in the standard Neovim data directory. Generally, this will be at `~/.local/share/nvim/hopper/hopper.db`.

### `float.width`, `float.height`

`integer` or `float`

Width and height of the standard floating windows. A value between 0 and 1 is treated as a percentage of available space. A value greater than 1 is treated as absolute characters.

These values are applied where they make sense; for example, the new project float will respect width, but not height since it's typically quite short by design.

### `colors`

`table<ColorName, string>`

Colors values are determined at setup time. They are mostly based on the values the current colorscheme applies to common highlight names.

Available color names:

- project: Used for project elements; defaults to "Statement" highlight
- action: Used for enabled actions in floating window footers; defaults to "Function" highlight
- first_key: Used for first key in keymap; defaults to "Exception" highlight
- second_key: Used for second key in keymap; defaults to "Special" highlight
- third_key: Used for third key in keymap; defaults to "Identifier" highlight
- fourth_key: Used for fourth key in keymap; defaults to "String" highlight

### `actions.display.special_keys`

`table<string, string>`

Choose custom display glyphs when showing actions in floating window footers. For example, to set `<esc>` to display as `ESC`, add entry

```
["<esc>"]: "ESC"
```

to the table. As it stands, this table is used mostly for displaying special keys using Nerdfont icons. That is, visual sugar.

Set to an empty table to disable.

### `actions.hopper.open_keymapper`

`string[]` or `string`

Keymaps to open keymapper float from within hopper float.

### `actions.hopper.open_picker`

`string[]` or `string`

Keymaps to open picker from within hopper float.

### `actions.hopper.open_project_menu`

`string[]` or `string`

Keymaps to open project menu from within hopper float.

### `actions.hopper.close`

`string[]` or `string`

Keymaps to close hopper float. 

### `actions.keymapper.confirm`

`string[]` or `string`

Keymaps to confirm new file keymapping.

### `actions.keymapper.accept_suggestion`

`string[]` or `string`

Keymaps to autocomplete keymap suggestion for file.

### `actions.keymapper.go_back`

`string[]` or `string`

Keymaps to return to previous float when applicable.

### `actions.keymapper.close`

`string[]` or `string`

Keymaps to close keymapper float.

### `actions.new_project.confirm`

`string[]` or `string`

Keymaps to confirm new project creation.

### `actions.new_project.accept_suggestion`

`string[]` or `string`

Keymaps to autocomplete new project suggestion.

### `actions.new_project.close`

`string[]` or `string`

Keymaps to close new project form.
