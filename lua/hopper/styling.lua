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

---@param name string
---@return string | nil
local function color_fg(name)
  local hl = vim.api.nvim_get_hl(0, {name = name, link = false}) or {}
  if type (hl.fg) == "number" then
    return string.format("#%06x", hl.fg)
  end
  return nil
end

---@param name string
---@return string | nil
local function color_bg(name)
  local hl = vim.api.nvim_get_hl(0, {name = name, link = false}) or {}
  if type (hl.bg) == "number" then
    return string.format("#%06x", hl.bg)
  end
  return nil
end

---@param from_hl string
---@param to_hl string
---@param overrides vim.api.keyset.highlight
local function _set_hl_inherited(from_hl, to_hl, overrides)
  local base_hl = vim.api.nvim_get_hl(0, {name = from_hl, link = false}) or {}
  local merged_hl = vim.tbl_extend("force", {}, base_hl, overrides or {})
  vim.api.nvim_set_hl(0, to_hl, merged_hl)
end

--- Blend two hex colors: fg over bg with opacity a (0..1).
--- Examples:
---   blend_hex_over("#FF0000", "#0000FF", 0.5) --> "#80007F"
---@param fg string
---@param bg string
---@param a decimal
local function blend_hex(fg, bg, a)
  local function to_rgb(hex)
    hex = hex:gsub("^#", "")
    if #hex == 3 then
      -- #RGB -> #RRGGBB
      hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
    end
    assert(#hex == 6, "hex must be #RGB or #RRGGBB")
    return tonumber(hex:sub(1,2), 16), tonumber(hex:sub(3,4), 16), tonumber(hex:sub(5,6), 16)
  end

  local function clamp01(x)
    if x < 0 then return 0 elseif x > 1 then return 1 else return x end
  end

  local fr, fg_, fb = to_rgb(fg)
  local br, bg_, bb = to_rgb(bg)
  a = clamp01(a)

  local function mix(fc, bc)
    local v = fc * a + bc * (1 - a)
    v = math.floor(v + 0.5)
    if v < 0 then v = 0 elseif v > 255 then v = 255 end
    return v
  end

  local r, g, b = mix(fr, br), mix(fg_, bg_), mix(fb, bb)
  return string.format("#%02X%02X%02X", r, g, b)
end


local function setup_higlights()
  local fg_color = color_fg("Normal")
  if not fg_color then
    fg_color = vim.o.background == "light" and "#000000" or "#ffffff"
  end
  local bg_color = color_bg("Normal")
  if not bg_color then
    bg_color = vim.o.background == "light" and "#ffffff" or "#000000"
  end
  local project_color = color_fg("Statement")
  local action_color = color_fg("Function")
  local first_key_color = color_fg("Exception")
  local second_key_color = color_fg("Special")
  local third_key_color = color_fg("Identifier")
  local fourth_key_color = color_fg("String")
  vim.api.nvim_set_hl(0, "hopper.MutedText", {fg = blend_hex(fg_color, bg_color, 0.7)})
  vim.api.nvim_set_hl(0, "hopper.DisabledText", {link = "Comment"})
  vim.api.nvim_set_hl(0, "hopper.ProjectText", {fg = project_color})
  vim.api.nvim_set_hl(0, "hopper.ProjectTag", {fg = bg_color, bg = project_color})
  vim.api.nvim_set_hl(0, "hopper.ActionText", {fg = action_color})
  vim.api.nvim_set_hl(0, "hopper.FirstKey", {fg = first_key_color})
  vim.api.nvim_set_hl(0, "hopper.FirstKeyNext", {fg = first_key_color, underline = true})
  vim.api.nvim_set_hl(0, "hopper.SecondKey", {fg = second_key_color})
  vim.api.nvim_set_hl(0, "hopper.SecondKeyNext", {fg = second_key_color, underline = true})
  vim.api.nvim_set_hl(0, "hopper.ThirdKey", {fg = third_key_color})
  vim.api.nvim_set_hl(0, "hopper.ThirdKeyNext", {fg = third_key_color, underline = true})
  vim.api.nvim_set_hl(0, "hopper.FourthKey", {fg = fourth_key_color})
  vim.api.nvim_set_hl(0, "hopper.FourthKeyNext", {fg = fourth_key_color, underline = true})

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
