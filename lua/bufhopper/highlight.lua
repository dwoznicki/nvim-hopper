local M = {}

local function set_highlights()
  -- vim.api.nvim_set_hl(0, "BufhopperKey", {fg = "#fdfd96"})
  vim.api.nvim_set_hl(0, "BufhopperKey", {fg = "#ff0000"})
  if vim.o.background == "dark" then
    vim.api.nvim_set_hl(0, "BufhopperFileName", {fg = "#fdfd96"})
    vim.api.nvim_set_hl(0, "BufhopperDirPath", {fg = "#636363"})
  else
    vim.api.nvim_set_hl(0, "BufhopperFileName", {fg = "#000000"})
  end
end

M.setup = function()
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = set_highlights,
  })
  set_highlights()
end

return M
