# Installation

## lazy,nvim

[lazy.nvim](https://github.com/folke/lazy.nvim)

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
