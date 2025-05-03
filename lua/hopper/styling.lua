-- local M = {}
--
-- local has_theme_kanagawa, kanagawa_colors_module = pcall(require, "kanagawa.colors")
-- if has_theme_kanagawa then
--   kanagawa_colors = kanagawa_colors_module.setup()
-- end
--
-- local function set_highlights()
--   -- vim.api.nvim_set_hl(0, "BufhopperJumpKey", {fg = "#f0a5c7"})
--   -- vim.api.nvim_set_hl(0, "BufhopperKey", {fg = "#fdfd96"})
--   -- vim.api.nvim_set_hl(0, "BufhopperCursorLine", {bg = "#343434"})
--   if has_theme_kanagawa then
--     vim.api.nvim_set_hl(0, "BufhopperCursorLine", {bg = kanagawa_colors.palette.sumiInk4})
--
--     vim.api.nvim_set_hl(0, "BufhopperModeNormal", {fg = kanagawa_colors.palette.sumiInk1, bg = kanagawa_colors.palette.springGreen})
--     vim.api.nvim_set_hl(0, "BufhopperModeJump", {fg = kanagawa_colors.palette.sumiInk1, bg = kanagawa_colors.palette.springBlue})
--
--     vim.api.nvim_set_hl(0, "BufhopperFileName", {fg = kanagawa_colors.palette.fujiWhite})
--     vim.api.nvim_set_hl(0, "BufhopperDirPath", {fg = kanagawa_colors.palette.fujiGray})
--     vim.api.nvim_set_hl(0, "BufhopperJumpKey", {fg = kanagawa_colors.palette.waveRed})
--     vim.api.nvim_set_hl(0, "BufhopperJumpKeyDisabled", {fg = kanagawa_colors.palette.fujiGray})
--
--     vim.api.nvim_set_hl(0, "BufhopperPaginationEnabled", {fg = kanagawa_colors.palette.fujiWhite})
--     vim.api.nvim_set_hl(0, "BufhopperPaginationDisabled", {fg = kanagawa_colors.palette.fujiGray})
--     vim.api.nvim_set_hl(0, "BufhopperPaginationKeyEnabled", {fg = kanagawa_colors.palette.waveRed})
--     vim.api.nvim_set_hl(0, "BufhopperPaginationKeyDisabled", {fg = kanagawa_colors.palette.fujiGray})
--   end
--   -- vim.api.nvim_set_hl(0, "BufhopperPaginationEnabled", {fg = "#ffffff"})
--   -- vim.api.nvim_set_hl(0, "BufhopperPaginationDisabled", {fg = "#aaaaaa"})
--   if vim.o.background == "dark" then
--     -- vim.api.nvim_set_hl(0, "BufhopperFileName", {fg = "#fdfd96"})
--     -- vim.api.nvim_set_hl(0, "BufhopperDirPath", {fg = "#636363"})
--   else
--     vim.api.nvim_set_hl(0, "BufhopperFileName", {fg = "#000000"})
--   end
-- end
--
-- function M.setup()
--   vim.api.nvim_create_autocmd("ColorScheme", {
--     pattern = "*",
--     callback = set_highlights,
--   })
--   set_highlights()
-- end
--
-- return M

---@class hopper.ColorPalette
---@field secondary_text string

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
    secondary_text = kanagawa_colors.palette.fujiGray,
  }
end

local function setup_higlights()
  local palette = try_load_kanagawa()
  if palette == nil then
    return
  end
  vim.api.nvim_set_hl(0, "hopper.hl.SecondaryText", {fg = palette.secondary_text})
end

function M.setup()
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = setup_higlights,
  })
  setup_higlights()
end

return M
