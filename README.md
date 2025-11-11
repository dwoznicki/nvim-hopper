# nvim-hopper

Hop around common files with mnemonic key mappings.

## Features

## Requirements

- neovim must be v0.10.0 or greater.
- sqlite3 must be installed, and ideally available on the $PATH. To check, run
  ```bash
  sqlite3 --version
  ```
  On Windows, the plugin will attempt to download the library, but this is best effort.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "dwoznicki/nvim-hopper",
  config = function()
    local hopper = require("hopper")
    hopper.setup()
    -- Optional, but recommended.
    vim.keymap.set("n", "<leader>u", hopper.toggle_hopper, {desc = "Toggle hopper"})
  end
}
```

## Usage

To create a file keymapping, open the file you want to map, then call `toggle_hopper` to open the hopper view. Press `<esc>` to enter normal mode, then `m` to open the keymapper. Type in the desired keymap, then `<cr>` to save. The given keymap is now stored for future use within the current project.

To open a file, call `toggle_hopper` then type in the keymap. Once you type in the last character, nvim-hopper will immediately attempt to open the mapped file.

## Configuration

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

## API

## Motivation

- **File picker**: Requires typing too many characters to reach a file. Especially when project contains multiple files with the same name.
- **Harpoon**: Good for coding sessions with just a few files. Not useful for navigating the project in a broader scope.
- **Buffer navigator**: Buffer needs to be open first.
