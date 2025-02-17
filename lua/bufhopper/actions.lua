local state = require("bufhopper.state")
local bl = require("bufhopper.buffer_list")
local fw = require("bufhopper.floating_window")

local M = {}

---Open the floating window.
function M.open()
  if state.current.float ~= nil and state.current.float:is_open() then
    vim.api.nvim_set_current_win(state.current.float.win)
    return
  end

  -- The buffer that we were on before opening the float.
  local current_buf = vim.api.nvim_get_current_buf()

  local buflist = bl.BufferList.new()
  state.set_buflist(buflist)
  buflist:populate_key_mappings()
  buflist:draw()
  local float = fw.FloatingWindow.new()
  state.set_float(float)
  float:open()
  buflist:cursor_to_buf(current_buf)
  state.get_mode_manager():set_mode(state.get_config().default_mode)

  -- local buflist_buf = Buflist.create_buf()
  -- State.state.buflist_buf = buflist_buf
  -- local buf_keys = Buflist.get_buf_keys(State.get_config())
  -- State.state.buflist_buf_keys = buf_keys
  -- local ui = vim.api.nvim_list_uis()[1]
  -- local _, win_width = Float.get_win_dimensions(ui, #buf_keys)
  -- Buflist.draw(buflist_buf, buf_keys, win_width)
  -- local float_win = Float.create_win(buflist_buf, ui)
  -- State.state.float_win = float_win
  -- Mode.set_mode("open")


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

  -- -- Close the float when the cursor leaves.
  -- vim.api.nvim_create_autocmd("WinLeave", {
  --   buffer = buflist_buf,
  --   once = true,
  --   callback = function()
  --     M.close()
  --   end,
  -- })

  -- vim.api.nvim_create_autocmd("BufWipeout", {
  --   buffer = buflist_buf,
  --   callback = function()
  --     State.state.float_win = nil
  --     State.state.buflist_buf = nil
  --     State.state.buflist_buf_keys = {}
  --   end,
  -- })

end

function M.close()
  if state.current.float ~= nil or not state.current.float:is_open() then
    return
  end
  state.current.float:close()
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
