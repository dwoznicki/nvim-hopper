---@class hopper.ColorPalette
---@field default_background string
---@field secondary_text string
---@field text_selection string
---@field first_key string
---@field second_key string
---@field project string

local M = {}

---@return hopper.ColorPalette | nil
local function try_load_kanagawa()
  local has_theme_kanagawa, kanagawa_colors_module = pcall(require, "kanagawa.colors")
  if not has_theme_kanagawa then
    return nil
  end
  local kanagawa_colors = kanagawa_colors_module.setup()
  ---@type hopper.ColorPalette
  return {
    default_background = kanagawa_colors.palette.sumiInk1,
    secondary_text = kanagawa_colors.palette.fujiGray,
    text_selection = kanagawa_colors.palette.waveBlue1,
    first_key = kanagawa_colors.palette.waveRed,
    second_key = kanagawa_colors.palette.springBlue,
    project = kanagawa_colors.palette.oniViolet,
  }
end

local function setup_higlights()
  local palette = try_load_kanagawa()
  if palette == nil then
    return
  end
  vim.api.nvim_set_hl(0, "hopper.hl.SecondaryText", {fg = palette.secondary_text})
  vim.api.nvim_set_hl(0, "hopper.hl.SelectedText", {bg = palette.text_selection})

  vim.api.nvim_set_hl(0, "hopper.hl.FirstKey", {fg = palette.first_key})
  vim.api.nvim_set_hl(0, "hopper.hl.FirstKeyNext", {fg = palette.first_key, underline = true})
  vim.api.nvim_set_hl(0, "hopper.hl.SecondKey", {fg = palette.second_key})
  vim.api.nvim_set_hl(0, "hopper.hl.SecondKeyNext", {fg = palette.second_key, underline = true})
  vim.api.nvim_set_hl(0, "hopper.hl.ProjectText", {fg = palette.project})
  vim.api.nvim_set_hl(0, "hopper.hl.ProjectTag", {fg = palette.default_background, bg = palette.project})

  vim.api.nvim_set_hl(0, "hopper.hl.FloatFooter", {fg = "#DCD7BA", bg = "#2A2A37"})
end

function M.setup()
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = setup_higlights,
  })
  setup_higlights()
end

return M
