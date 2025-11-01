local BaseFilename = require("lualine.components.filename")
local hl = require("lualine.highlight")
local projects = require("hopper.projects")
local keymaps = require("hopper.keymaps")
local datastore = require("hopper.db").datastore()
local styling = require("hopper.styling")

local HopperFilename = BaseFilename:extend()

function HopperFilename:init(opts)
  HopperFilename.super.init(self, opts)
  local key_colors = styling.key_colors()
  -- Pre-calculate the colors. We'll convert them to Lualine "%#hlgroup#...%" codes at update time
  -- to avoid all highlights being marked as inactive.
  self.hopper_highlight_name_to_lualine_highlight_group = {
    [""] = hl.create_component_highlight_group({}, "hopper_default", self.options),
    ["hopper.FirstKey"] = hl.create_component_highlight_group({fg = key_colors.first_key}, "hopper_first_key", self.options),
    ["hopper.SecondKey"] = hl.create_component_highlight_group({fg = key_colors.second_key}, "hopper_second_key", self.options),
    ["hopper.ThirdKey"] = hl.create_component_highlight_group({fg = key_colors.third_key}, "hopper_third_key", self.options),
    ["hopper.FourthKey"] = hl.create_component_highlight_group({fg = key_colors.fourth_key}, "hopper_fourth_key", self.options),
  }
end

function HopperFilename:update_status()
  local orig_filename = HopperFilename.super.update_status(self)
  if orig_filename == "" then
    return orig_filename
  end
  local project = projects.current_project()
  local file_path = vim.api.nvim_buf_get_name(0)
  local path = projects.path_from_project_root(project.path, file_path)
  local file_keymap = datastore:get_file_keymap_by_path(project.name, path)
  if file_keymap == nil then
    return orig_filename
  end
  -- We hae to assume the Lualine filename includes the path. Otherwise, the hgihlighted parts won't
  -- match what we show in the file list. Not that big of a deal.
  local keymap_indexes = keymaps.keymap_location_in_path(orig_filename, file_keymap.keymap, {missing_behavior = "end", case_matching = "smart"})
  local path_line = keymaps.highlight_path_virtual_text(orig_filename, file_keymap.keymap, keymap_indexes, {default_highlight_name = ""})
  local joined_path = ""
  for _, text_and_hl_name in ipairs(path_line) do
    local text, hopper_hl_name = text_and_hl_name[1], text_and_hl_name[2]
    local lualine_hl_group = self.hopper_highlight_name_to_lualine_highlight_group[hopper_hl_name]
    if lualine_hl_group == nil then
      lualine_hl_group = self.hopper_highlight_name_to_lualine_highlight_group[""]
    end
    joined_path = joined_path .. hl.component_format_highlight(lualine_hl_group) .. text
  end
  return joined_path
end

return HopperFilename
