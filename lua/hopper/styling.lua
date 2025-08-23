---@class hopper.ColorPalette
---@field default_background string
---@field muted string
---@field disabled string
---@field project string
---@field action string
---@field first_key string
---@field second_key string
---@field third_key string
---@field fourth_key string

local M = {}

---@param from_hl string
---@param to_hl string
---@param overrides vim.api.keyset.highlight
local function _set_hl_inherited(from_hl, to_hl, overrides)
  local base_hl = vim.api.nvim_get_hl(0, { name = from_hl, link = false }) or {}
  local merged_hl = vim.tbl_extend("force", {}, base_hl, overrides or {})
  vim.api.nvim_set_hl(0, to_hl, merged_hl)
end

---@return hopper.ColorPalette | nil
local function try_load_kanagawa()
  local success, kanagawa_colors = pcall(require, "kanagawa.colors")
  if not success then
    return nil
  end
  local colors = kanagawa_colors.setup()
  ---@type hopper.ColorPalette
  return {
    default_background = colors.palette.sumiInk1,
    muted = colors.palette.fujiGray,
    disabled = colors.palette.fujiGray,
    project = colors.palette.oniViolet,
    action = colors.palette.crystalBlue,
    first_key = colors.palette.waveRed,
    second_key = colors.palette.springBlue,
    third_key = colors.palette.carpYellow,
    fourth_key = colors.palette.springGreen,
  }
end

local function setup_higlights()
  local palette = try_load_kanagawa()
  if palette == nil then
    return
  end
  -- #727169
  vim.api.nvim_set_hl(0, "hopper.MutedText", {fg = palette.muted})
  vim.api.nvim_set_hl(0, "hopper.DisabledText", {link = "Comment"})
  vim.api.nvim_set_hl(0, "hopper.ProjectText", {fg = palette.project})
  vim.api.nvim_set_hl(0, "hopper.ProjectTag", {fg = palette.default_background, bg = palette.project})
  vim.api.nvim_set_hl(0, "hopper.ActionText", {fg = palette.action})
  vim.api.nvim_set_hl(0, "hopper.FirstKey", {fg = palette.first_key})
  vim.api.nvim_set_hl(0, "hopper.FirstKeyNext", {fg = palette.first_key, underline = true})
  vim.api.nvim_set_hl(0, "hopper.SecondKey", {fg = palette.second_key})
  vim.api.nvim_set_hl(0, "hopper.SecondKeyNext", {fg = palette.second_key, underline = true})
  vim.api.nvim_set_hl(0, "hopper.ThirdKey", {fg = palette.third_key})
  vim.api.nvim_set_hl(0, "hopper.ThirdKeyNext", {fg = palette.third_key, underline = true})
  vim.api.nvim_set_hl(0, "hopper.FourthKey", {fg = palette.fourth_key})
  vim.api.nvim_set_hl(0, "hopper.FourthKeyNext", {fg = palette.fourth_key, underline = true})

  vim.api.nvim_set_hl(0, "hopper.FloatFooter", {fg = "#DCD7BA", bg = "#2A2A37"})
end

function M.setup()
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = setup_higlights,
  })
  setup_higlights()
end

return M
