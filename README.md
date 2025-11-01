# nvim-hopper

Hop around common files with mnemonic key mappings.

## Features

## Requirements

- neovim must be v0.10.0 or greater.
- sqlite3 must be available on the path. To check, run
  ```bash
  sqlite3 --version
  ```

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "dwoznicki/nvim-hopper",
  config = function()
    local hopper = require("hopper")
    hopper.setup()
    vim.keymap.set("n", "<leader>u", hopper.toggle_hopper, {desc = "Toggle hopper"})
  end
}
```

## Motivation

- **File picker**: Requires typing too many characters to reach a file. Especially when project contains multiple files with the same name.
- **Harpoon**: Good for coding sessions with just a few files. Not useful for navigating the project in a broader scope.
- **Buffer navigator**: Buffer needs to be open first.
