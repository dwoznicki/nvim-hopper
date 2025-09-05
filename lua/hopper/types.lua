---@alias hopper.Project {name: string, path: string}
---@alias hopper.FileKeymap {id: integer, project: string, path: string, keymap: string}

---@class hopper.Options
---@field keymapping hopper.KeymappingOptions | nil
---@field db hopper.DatabaseOptions | nil
---@field float hopper.FloatOptions | nil
---@field colors hopper.ColorPalette | nil
---@field actions hopper.ActionOptions | nil

---@class hopper.KeymappingOptions
---@field keyset string | string[] | nil
---@field length integer | nil
---@field default_open_cmd string | nil "edit", "split", "vsplit"

---@class hopper.DatabaseOptions
---@field sqlite_path string | nil
---@field database_path string | nil

---@class hopper.FloatOptions
---@field width integer | decimal | nil
---@field height integer | decimal | nil

---@class hopper.ColorPalette
---@field muted string | nil
---@field disabled string | nil
---@field project string | nil
---@field action string | nil
---@field first_key string | nil
---@field second_key string | nil
---@field third_key string | nil
---@field fourth_key string | nil

---@alias hopper.HopperViewAction "open_keymapper" | "open_project_menu" | "open_picker" | "close"
---@alias hopper.KeymapperViewAction "confirm" | "accept_suggestion" | "go_back" | "close"
---@alias hopper.NewProjectViewAction "confirm" | "accept_suggestion" | "close"

---@class hopper.ActionOptions
---@field hopper table<hopper.HopperViewAction, string | string[] | nil> | nil
---@field keymapper table<hopper.HopperViewAction, string | string[] | nil> | nil
---@field new_project table<hopper.HopperViewAction, string | string[] | nil> | nil
