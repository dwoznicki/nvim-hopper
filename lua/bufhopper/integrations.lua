local M = {}

---@param buf integer
function M.clear_whichkey(buf)
  local whichkey_loaded, whichkey = pcall(require, "which-key")
  if not whichkey_loaded then
    return
  end
  local whichkey_buf = require("which-key.buf")
  -- print("clearing which key")
  whichkey_buf.clear({buf = buf})
end

-- function M.setup()
--   vim.api.nvim_create_autocmd("FileType", {
--     pattern = "BufhopperFloat",
--     callback = function()
--       local whichkey_config_loaded, whichkey_config = pcall(require, "which-key.config")
--       if not whichkey_config_loaded then
--         return
--       end
--       -- if not vim.list_contains(whichkey_config.disable.ft, "BufhopperFloat") then
--       --   table.insert(whichkey_config.disable.ft, "BufhopperFloat")
--       -- end
--       -- pcall(vim.keymap.del, "n", "g", {buffer = 0})
--       -- pcall(vim.keymap.del, "n", "z", {buffer = 0})
--       local whichkey_buf = require("which-key.buf")
--       whichkey_buf.clear({buf = 0})
--     end,
--   })
-- end

return M
