local M = {}

---@alias BufhopperConfig.keyset "alpha" | "numeric" | "alphanumeric" | string[]
---@alias BufhopperConfig.next_key "sequential" | "filename" | fun(context: BufhopperNextKeyContext): string | nil

---@class BufhopperConfig
---@field default_mode BufhopperMode
---@field jump_mode BufhopperJumpModeConfig
---@field normal_mode BufhopperNormalModeConfig
---@field buffers BufhopperBuffersConfig

---@class BufhopperBuffersConfig
---@field show_unloaded boolean
---@field show_hidden boolean
---@field pagination BufhopperPaginationConfig

---@class BufhopperPaginationConfig
---@field enabled boolean
---@field actions BufhopperPaginationActionsConfig

---@class BufhopperPaginationActionsConfig
---@field next_page string
---@field prev_page string

---@class BufhopperJumpModeConfig
---@field delay integer
---@field keyset BufhopperConfig.keyset
---@field next_key BufhopperConfig.next_key

---@class BufhopperNormalModeConfig
---@field actions BufhopperNormalModeActionsConfig

---@class BufhopperNormalModeActionsConfig
---@field open_buffer string
---@field vertical_split_buffer string
---@field horizontal_split_buffer string

---@class BufhopperOptions
---@field default_mode? BufhopperMode
---@field jump_mode? BufhopperJumpModeOptions
---@field normal_mode? BufhopperNormalModeOptions
---@field buffers? BufhopperBuffersOptions

---@class BufhopperBuffersOptions
---@field show_unloaded? boolean default = true
---@field show_hidden? boolean default = false
---@field pagination? BufhopperPaginationOptions

---@class BufhopperPaginationOptions
---@field enabled? boolean default = true
---@field actions? BufhopperPaginationActionsOptions

---@class BufhopperPaginationActionsOptions
---@field next_page? string Go to next page of buffers. default = "N"
---@field prev_page? string Go to previous page of buffers. default = "P"

---@class BufhopperJumpModeOptions
---@field delay? integer Delay in milliseconds before opening buffer. Set to 0 for no delay. default = 50
---@field keyset? BufhopperConfig.keyset
---@field next_key? BufhopperConfig.next_key

---@class BufhopperNormalModeOptions
---@field actions? BufhopperNormalModeActionsOptions

---@class BufhopperNormalModeActionsOptions
---@field open_buffer? string Open buffer under cursor in main window. default = ["oo", "<cr>"]
---@field vertical_split_buffer? string Open buffer under cursor in vertical split. default = "ov"
---@field horizontal_split_buffer? string Open buffer under cursor in horizontal split. default = "oh"


function M.default_config()
  ---@type BufhopperConfig
  return {
    default_mode = "jump",
    jump_mode = {
      delay = 50,
      keyset = "alphanumeric",
      next_key = "filename",
    },
    normal_mode = {
      actions = {
        open_buffer = "<cr>",
        vertical_split_buffer = "ov",
        horizontal_split_buffer = "oh",
      },
    },
    buffers = {
      show_unloaded = true,
      show_hidden = false,
      pagination = {
        enabled = true,
        actions = {
          next_page = "N",
          prev_page = "P",
        },
      },
    },
  }
end

return M
