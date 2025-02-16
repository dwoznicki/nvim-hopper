---@class BufhopperNextKeyContext
---@field config BufhopperConfigState
---@field mapped_keys table<string, integer>
---@field keyset string[]
---@field prev_key string | nil
---@field key_index integer
---@field file_name string

---@alias BufhopperConfigState.keyset "alpha" | "numeric" | "ergonomic" | string[]
---@alias BufhopperConfigState.next_key "sequential" | "filename" | function(context: BufhopperNextKeyContext): string | nil

---@class BufhopperConfigState
---@field keyset BufhopperConfigState.keyset
---@field next_key BufhopperConfigState.next_key

---@class BufhopperOptions
---@field keyset? BufhopperConfigState.keyset
---@field next_key? BufhopperConfigState.next_key

---@class BufhopperBuflistState
---@field buf integer | nil
---@field buf_keys table<BufferKeyMapping>

---@class BufferKeyMapping
---@field key string
---@field buf integer
---@field file_name string
---@field file_path string
---@field file_path_tokens string[]
---@field buf_indicators string

---@class BufhopperFloatState
---@field win integer | nil

---@alias mode "open" | "jump" | "delete"

---@class BufhopperModeState
---@field mode mode | nil

---@class BufhopperModeLifecycle
---@field setup function()
---@field teardown function()
