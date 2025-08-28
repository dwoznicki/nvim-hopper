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

---@class hopper.ActionOptions
---@field hopper_open_keymapper string | string[] | nil
---@field hopper_open_projects_menu string | string[] | nil
---@field hopper_close string | string[] | nil
---@field keymapper_confirm string | string[] | nil
---@field keymapper_accept_suggestion string | string[] | nil
---@field keymapper_go_back string | string[] | nil
---@field keymapper_close string | string[] | nil
---@field new_project_confirm string | string[] | nil
---@field new_project_accept_suggestion string | string[] | nil
---@field new_project_close string | string[] | nil
