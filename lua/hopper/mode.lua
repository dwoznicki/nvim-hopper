local state = require("hopper.state")

---@alias BufhopperMode "jump" | "normal"

local M = {}

---@class BufhopperModeManager
---@field mode BufhopperMode | nil
---@field create fun(): BufhopperModeManager
---@field set_mode fun(self: BufhopperModeManager, mode: BufhopperMode): nil
local ModeManager = {}
ModeManager.__index = ModeManager

function ModeManager.create()
  local mode_manager = {}
  setmetatable(mode_manager, ModeManager)
  state.set_mode_manager(mode_manager)
  return mode_manager
end

function ModeManager:set_mode(mode)
  local prev_mode = self.mode
  if mode == "normal" then
    if prev_mode == "jump" then
      self:remove_jump_mode_keymaps()
    end
    self:add_normal_mode_keymaps()
  elseif mode == "jump" then
    if prev_mode == "normal" then
      self:remove_normal_mode_keymaps()
    end
    self:add_jump_mode_keymaps()
  end
  self.mode = mode
  vim.schedule(
    function()
      state.get_buffer_table():draw()
      state.get_status_line():draw()
    end
  )

  -- if mode ~= "jump" then
  --   vim.keymap.set(
  --     "n",
  --     "<esc>",
  --     function()
  --       M.set_mode("jump")
  --     end,
  --     {silent = true, nowait = true, buffer = State.get_buflist_buf()}
  --   )
  -- end

end

function ModeManager:add_jump_mode_keymaps()
  local tbl = state.get_buffer_table()
  local buflist = state.get_buffer_list()
  local config = state.get_config()

  for key, buffer in pairs(buflist.buffers_by_key) do
    pcall(vim.keymap.del, "n", key, {buffer = tbl.buf})
    vim.keymap.set(
      "n",
      key,
      function()
        if buffer == -1 then
          vim.notify("Key '" .. key .. "' not mapped to buffer.", vim.log.levels.INFO)
          return
        end
        if config.jump_mode ~= nil and config.jump_mode.delay ~= nil and config.jump_mode.delay > 0 then
          tbl:cursor_to_buf(buffer.buf)
          vim.defer_fn(
            function()
              state.get_floating_window():close()
              vim.api.nvim_set_current_buf(buffer.buf)
            end,
            config.jump_mode.delay
          )
        else
          state.get_floating_window():close()
          vim.api.nvim_set_current_buf(buffer.buf)
        end
      end,
      {noremap = true, silent = true, nowait = true, buffer = tbl.buf}
    )
  end

  vim.keymap.set(
    "n",
    "<esc>",
    function()
      self:set_mode("normal")
    end,
    {noremap = true, buffer = tbl.buf}
  )

  -- -- Add buffer specific jump keymaps.
  -- for i, buffer in ipairs(buffers) do
  --   if buffer.key ~= nil then
  --     vim.keymap.set(
  --       "n",
  --       buffer.key,
  --       function()
  --         vim.api.nvim_set_current_buf(buffer.buf)
  --         vim.api.nvim_win_set_cursor(buftable.win, {i, 0})
  --         if self.mode == "open" then
  --           vim.defer_fn(
  --             function()
  --               state.get_floating_window():close()
  --               vim.api.nvim_set_current_buf(buffer.buf)
  --             end,
  --             50
  --           )
  --           return
  --         end
  --       end,
  --       {noremap = true, silent = true, nowait = true, buffer = buftable.buf}
  --     )
  --   end
  -- end

  -- -- Add buffer selection keymaps.
  -- vim.keymap.set(
  --   "n",
  --   "<cr>",
  --   function()
  --     local buf_key, _ = utils.get_buf_key_under_cursor(buftable.win, buffers)
  --     if buf_key ~= nil then
  --       state.get_floating_window():close()
  --       vim.api.nvim_set_current_buf(buf_key.buf)
  --     end
  --   end,
  --   {silent = true, remap = false, nowait = true, buffer = buftable.buf}
  -- )

  -- vim.keymap.set(
  --   "n",
  --   "H",
  --   function()
  --     local buf_key, _ = utils.get_buf_key_under_cursor(buftable.win, buffers)
  --     if buf_key ~= nil then
  --       vim.cmd("split")
  --       local split_win = vim.api.nvim_get_current_win()
  --       vim.api.nvim_win_set_buf(split_win, buf_key.buf)
  --     end
  --   end,
  --   {silent = true, nowait = true, buffer = buftable.buf}
  -- )

  -- vim.keymap.set(
  --   "n",
  --   "V",
  --   function()
  --     local buf_key, _ = utils.get_buffer_key_under_cursor(buftable.win, buffers)
  --     if buf_key ~= nil then
  --       vim.cmd("vsplit")
  --       local split_win = vim.api.nvim_get_current_win()
  --       vim.api.nvim_win_set_buf(split_win, buf_key.buf)
  --     end
  --   end,
  --   {silent = true, nowait = true, buffer = buftable.buf}
  -- )

  -- -- Add enter delete mode keymaps.
  -- vim.keymap.set(
  --   "n",
  --   "d",
  --   function()
  --     self:set_mode("delete")
  --     vim.o.operatorfunc = "v:lua.bufhopper_delete_operator"
  --     -- Handle "dd" keymap.
  --     vim.keymap.set("o", "d", "$", {noremap = true, buffer = buftable.buf})
  --     return "g@"
  --   end,
  --   {expr = true, noremap = true, buffer = buftable.buf}
  -- )

end

-- function _G.bufhopper_delete_operator()
--   local buftable = state.get_buffer_table()
--   local buflist = state.get_buffer_list()
--   local start_mark = vim.api.nvim_buf_get_mark(buftable.buf, "[")
--   local end_mark = vim.api.nvim_buf_get_mark(buftable.buf, "]")
--   local cursor_pos = vim.api.nvim_win_get_cursor(buftable.win)
--   if start_mark[1] == end_mark[1] then
--     buflist:remove_at_index(start_mark[1])
--   else
--     buflist:remove_in_index_range(start_mark[1], end_mark[1])
--   end
--   buflist:populate()
--   buftable:draw()
--   if #buflist.buffers > 0 then
--     if cursor_pos[1] > #buflist.buffers then
--       cursor_pos[1] = cursor_pos[1] - 1
--     end
--     state.get_buffer_table():cursor_to_row(cursor_pos[1])
--   end
--   state.get_mode_manager():revert_to_last_stable_mode()
-- end


-- function ModeManager:add_delete_mode_keymaps()
--   local buftable = state.get_buffer_table()
--   -- Cancel delete mode when the user presses escape.
--   vim.keymap.set(
--     {"o", "n"},
--     "<esc>",
--     function()
--       self:revert_to_last_stable_mode()
--       return "<esc>"
--     end,
--     {expr = true, noremap = true, buffer = buftable.buf}
--   )
-- end

function ModeManager:remove_jump_mode_keymaps()
  local tbl = state.get_buffer_table()
  local buflist = state.get_buffer_list()

  for key, _ in pairs(buflist.buffers_by_key) do
    pcall(vim.keymap.del, "n", key, {buffer = tbl.buf})
  end

  pcall(vim.keymap.del, "n", "<esc>", {buffer = tbl.buf})

  -- -- Remove buffer selection keymaps.
  -- pcall(vim.keymap.del, "n", "<cr>", {buffer = tbl.buf})
  -- pcall(vim.keymap.del, "n", "H", {buffer = tbl.buf})
  -- pcall(vim.keymap.del, "n", "V", {buffer = tbl.buf})
  -- -- Remove enter delete mode keymaps.
  -- pcall(vim.keymap.del, "n", "d", {buffer = tbl.buf})
  -- pcall(vim.keymap.del, "o", "d", {buffer = tbl.buf})

end

function ModeManager:add_normal_mode_keymaps()
  local tbl = state.get_buffer_table()
  local conf = state.get_config()

  vim.keymap.set(
    "n",
    "J",
    function()
      self:set_mode("jump")
    end,
    {noremap = true, nowait = true, buffer = tbl.buf}
  )

  -- vim.keymap.set(
  --   "n",
  --   "d",
  --   function()
  --     vim.o.operatorfunc = "v:lua.bufhopper_delete_operator"
  --     -- Handle "dd" keymap.
  --     -- vim.keymap.set("o", "d", "$", {noremap = true, buffer = buftable.buf})
  --     return "g@"
  --   end,
  --   {expr = true, noremap = true, buffer = tbl.buf}
  -- )

  vim.keymap.set(
    "n",
    "d",
    function()
      vim.o.operatorfunc = "v:lua.bufhopper_delete_operator"
      -- Handle "dd" keymap.
      vim.keymap.set("o", "d", "$", {noremap = true, nowait = true, buffer = tbl.buf})
      -- Remove the "dd" keymap when mode changes back to normal.
      vim.api.nvim_create_autocmd("ModeChanged", {
        pattern = "n:no",
        callback = function()
          -- Remove async to avoid canceling out the operator function call, which actually deletes
          -- the buffer.
          vim.schedule(
            function()
              vim.keymap.del("o", "d", {buffer = tbl.buf})
            end
          )
        end,
        once = true
      })
      return "g@"
    end,
    {expr = true, noremap = true, buffer = tbl.buf}
  )

  vim.keymap.set(
    "n",
    "<esc>",
    function()
      state.get_floating_window():close()
    end,
    {noremap = true, buffer = tbl.buf}
  )
  vim.keymap.set(
    "n",
    "q",
    function()
      state.get_floating_window():close()
    end,
    {noremap = true, buffer = tbl.buf}
  )

  vim.keymap.set(
    "n",
    conf.normal_mode.actions.open_buffer,
    function()
      local buffer = tbl:buffer_under_cursor()
      if buffer ~= nil then
        state.get_floating_window():close()
        vim.api.nvim_set_current_buf(buffer.buf)
      end
    end,
    {noremap = true, nowait = true, buffer = tbl.buf}
  )

  vim.keymap.set(
    "n",
    conf.normal_mode.actions.vertical_split_buffer,
    function()
      local buffer = tbl:buffer_under_cursor()
      if buffer ~= nil then
        state.get_floating_window():close()
        vim.cmd("vsplit")
        local split_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(split_win, buffer.buf)
        -- state.get_floating_window():close()
        -- vim.api.nvim_set_current_buf(buffer.buf)
      end
    end,
    {noremap = true, nowait = true, buffer = tbl.buf}
  )

  vim.keymap.set(
    "n",
    conf.normal_mode.actions.horizontal_split_buffer,
    function()
      local buffer = tbl:buffer_under_cursor()
      if buffer ~= nil then
        state.get_floating_window():close()
        vim.cmd("split")
        local split_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(split_win, buffer.buf)
        -- state.get_floating_window():close()
        -- vim.api.nvim_set_current_buf(buffer.buf)
      end
    end,
    {noremap = true, nowait = true, buffer = tbl.buf}
  )
end

function _G.bufhopper_delete_operator()
  local tbl = state.get_buffer_table()
  local buflist = state.get_buffer_list()

  local start_mark = vim.api.nvim_buf_get_mark(tbl.buf, "[")
  local end_mark = vim.api.nvim_buf_get_mark(tbl.buf, "]")
  local cursor_pos = vim.api.nvim_win_get_cursor(tbl.win)
  if start_mark[1] == end_mark[1] then
    buflist:remove_at_index(start_mark[1])
  else
    buflist:remove_in_index_range(start_mark[1], end_mark[1])
  end
  buflist:populate()
  tbl:draw()
  if #buflist.buffers > 0 then
    if cursor_pos[1] > #buflist.buffers then
      cursor_pos[1] = cursor_pos[1] - 1
    end
    tbl:cursor_to_row(cursor_pos[1])
  end
end

function ModeManager:remove_normal_mode_keymaps()
  local tbl = state.get_buffer_table()
  local conf = state.get_config()

  pcall(vim.keymap.del, "n", "d", {buffer = tbl.buf})
  pcall(vim.keymap.del, "n", "<esc>", {buffer = tbl.buf})
  pcall(vim.keymap.del, "n", "q", {buffer = tbl.buf})

  pcall(vim.keymap.del, "n", conf.normal_mode.actions.open_buffer, {buffer = tbl.buf})
  pcall(vim.keymap.del, "n", conf.normal_mode.actions.vertical_split_buffer, {buffer = tbl.buf})
  pcall(vim.keymap.del, "n", conf.normal_mode.actions.horizontal_split_buffer, {buffer = tbl.buf})
end

M.ModeManager = ModeManager

return M
