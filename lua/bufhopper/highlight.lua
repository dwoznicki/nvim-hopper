local M = {}

local has_theme_kanagawa, kanagawa_colors_module = pcall(require, "kanagawa.colors")
if has_theme_kanagawa then
  kanagawa_colors = kanagawa_colors_module.setup()
end

local function set_highlights()
  -- vim.api.nvim_set_hl(0, "BufhopperKey", {fg = "#fdfd96"})
  vim.api.nvim_set_hl(0, "BufhopperKey", {fg = "#f0a5c7"})
  vim.api.nvim_set_hl(0, "BufhopperCursorLine", {bg = "#343434"})
  if has_theme_kanagawa then
    vim.api.nvim_set_hl(0, "BufhopperModeOpen", {fg = kanagawa_colors.palette.sumiInk1, bg = kanagawa_colors.palette.springGreen})
    vim.api.nvim_set_hl(0, "BufhopperModeJump", {fg = kanagawa_colors.palette.sumiInk1, bg = kanagawa_colors.palette.springBlue})
    vim.api.nvim_set_hl(0, "BufhopperModeDelete", {fg = kanagawa_colors.palette.sumiInk1, bg = kanagawa_colors.palette.autumnRed})
  end
  vim.api.nvim_set_hl(0, "BufhopperPaginationEnabled", {fg = "#ffffff"})
  vim.api.nvim_set_hl(0, "BufhopperPaginationDisabled", {fg = "#aaaaaa"})
  if vim.o.background == "dark" then
    vim.api.nvim_set_hl(0, "BufhopperFileName", {fg = "#fdfd96"})
    vim.api.nvim_set_hl(0, "BufhopperDirPath", {fg = "#636363"})
  else
    vim.api.nvim_set_hl(0, "BufhopperFileName", {fg = "#000000"})
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = set_highlights,
  })
  set_highlights()
end

return M
