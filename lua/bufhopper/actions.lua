local Float = require("bufhopper.float")
local Buflist = require("bufhopper.buflist")
local Mode = require("bufhopper.mode")

local M = {}

---Open the floating window.
function M.open()
  if Float.is_open() then
    vim.api.nvim_set_current_win(Float.get_win())
    return
  end


  Buflist.populate_buf_keys()
  Buflist.setup_buf()
  Buflist.draw()
  Float.open_win(Buflist.get_buf())
  Mode.set_mode("open")

  -- The buffer that we were on before opening the float.
  local current_buf = vim.api.nvim_get_current_buf()

  for i, buffer_key in ipairs(Buflist.state.buf_keys) do
    if buffer_key.buf == current_buf then
      vim.api.nvim_win_set_cursor(Float.get_win(), {i, 0})
      break
    end
  end

  -- vim.keymap.set(
  --   "n",
  --   "dd",
  --   function()
  --     local buffer_key, idx = get_buffer_key_under_cursor(buffer_keys, buffers_win)
  --     if buffer_key ~= nil then
  --       local cursor_pos = vim.api.nvim_win_get_cursor(buffers_win)
  --       vim.api.nvim_buf_delete(buffer_key.buf, {})
  --       table.remove(buffer_keys, idx)
  --       draw_buffer_lines(buffers_buf, buffer_keys)
  --       if #buffer_keys > 0 then
  --         if cursor_pos[1] > #buffer_keys then
  --           cursor_pos[1] = cursor_pos[1] - 1
  --         end
  --         vim.api.nvim_win_set_cursor(buffers_win, cursor_pos)
  --       end
  --       -- if cursor_pos[1] > 1 then
  --       --   vim.api.nvim_win_set_cursor(buffers_win, {cursor_pos[1] - 1, cursor_pos[2]})
  --       -- else
  --       --   if #buffer_keys > 1 then
  --       --     vim.api.nvim_win_set_cursor(buffers_win, cursor_pos)
  --       --   end
  --       -- end
  --     end
  --   end,
  --   {silent = true, nowait = true, buffer = buffers_buf}
  -- )

  -- Close the float when the cursor leaves.
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = Buflist.get_buf(),
    once = true,
    callback = function()
      M.close()
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = Buflist.get_buf(),
    callback = function()
      Float.state.win = nil
      Buflist.state.buf = nil
      Buflist.state.buf_keys = {}
    end,
  })
end

function M.close()
  if Float.state.win ~= nil and vim.api.nvim_win_is_valid(Float.state.win) then
    vim.api.nvim_win_close(Float.state.win, true)
  end
end

function M.delete_other_buffers()
  M.close()
  local curbuf = vim.api.nvim_get_current_buf()
  local num_closed = 0
  for _, openbuf in ipairs(vim.api.nvim_list_bufs()) do
    if not vim.api.nvim_buf_is_loaded(openbuf) or vim.api.nvim_get_option_value("buftype", {buf = openbuf}) ~= "" then
      goto continue
    end
    if openbuf == curbuf then
      goto continue
    end
    vim.api.nvim_buf_delete(openbuf, {})
    num_closed = num_closed + 1
    ::continue::
  end
  print(num_closed .. " buffers closed")
end

-- ---@param mode mode
-- function M.set_mode(mode)
--   ---@type [string, string]
--   local footer_text
--   if mode == "open" then
--     footer_text = {" Open ", "BufhopperFooterModeOpen"}
--   elseif mode == "delete" then
--     footer_text = {" Delete ", "BufhopperFooterModeDelete"}
--   else
--     footer_text = {" Jump ", "BufhopperFooterModeJump"}
--   end
--   local config = {
--     footer = {{" ", ""}, footer_text, {" ", ""}},
--     footer_pos = "left",
--   }
--   vim.api.nvim_win_set_config(M._buffers_win, config)
--   M._keypress_mode = mode
--   if mode == "open" then
--     vim.keymap.set(
--       "n",
--       "<esc>",
--       function()
--         M.set_mode("jump")
--       end,
--       {silent = true, nowait = true, buffer = M._buffers_buf}
--     )
--   elseif mode == "delete" then
--     draw_buffer_lines(M._buffers_buf, M._buffer_keys, {hide_keymapping = true})
--     remove_buffer_keymappings(M._buffers_buf, M._buffer_keys)
--     vim.keymap.set(
--       "n",
--       "<esc>",
--       function()
--         M.set_mode("jump")
--       end,
--       {silent = true, nowait = true, buffer = M._buffers_buf}
--     )
--   else
--     -- vim.keymap.set("n", "<esc>", ":q<cr>", {silent = true, nowait = true, buffer = M._buffers_buf})
--     pcall(
--       vim.keymap.del,
--       "n",
--       "<esc>",
--       {buffer = M._buffers_buf}
--     )
--   end
-- end

return M
