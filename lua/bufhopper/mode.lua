local utils = require("bufhopper.utils")
local state = require("bufhopper.state")

---@alias BufhopperMode "open" | "jump" | "delete"

local M = {}

---@class BufhopperModeManager
---@field mode BufhopperMode | nil
---@field prev_mode BufhopperMode | nil
---@field create fun(): BufhopperModeManager
---@field set_mode fun(self: BufhopperModeManager, mode: BufhopperMode): nil
---@field revert_mode fun(self: BufhopperModeManager): nil
---@field setup fun(self: BufhopperModeManager): nil
---@field teardown fun(self: BufhopperModeManager): nil
local ModeManager = {}
ModeManager.__index = ModeManager

function ModeManager.create()
  local mode_manager = {}
  setmetatable(mode_manager, ModeManager)
  state.set_mode_manager(mode_manager)
  return mode_manager
end

function ModeManager:set_mode(mode)
  self:teardown()
  self.prev_mode = self.mode
  self.mode = mode
  self:setup()
  vim.schedule(
    function()
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

function ModeManager:revert_mode()
  self:set_mode(self.prev_mode)
end

function ModeManager:setup()
  if self.mode == "jump" then
    self:add_buflist_jump_keymappings()
    self:add_buflist_select_keymappings()
    self:add_enter_delete_mode_keymapping()
  elseif self.mode == "open" then
    self:add_buflist_jump_keymappings()
    self:add_jk_escape_hatch_keymappings()
    self:add_enter_delete_mode_keymapping()
  elseif self.mode == "delete" then
    self:add_cancel_keymapping()
  end
end

function ModeManager:teardown()
  if self.mode == "jump" then
    self:remove_buflist_jump_keymappings()
    self:remove_buflist_select_keymappings()
    self:remove_enter_delete_mode_keymapping()
  elseif self.mode == "open" then
    self:remove_buflist_jump_keymappings()
    self:remove_jk_escape_hatch_keymappings()
    self:remove_enter_delete_mode_keymapping()
  elseif self.mode == "delete" then
    self:remove_cancel_keymapping()
  end
end

function ModeManager:add_buflist_jump_keymappings()
  local buftable = state.get_buffer_table()
  local buffers = state.get_buffer_list().buffers
  for i, buffer in ipairs(buffers) do
    vim.keymap.set(
      "n",
      buffer.key,
      function()
        vim.api.nvim_win_set_cursor(buftable.win, {i, 0})
        if self.mode == "open" then
          vim.defer_fn(
            function()
              state.get_floating_window():close()
              vim.api.nvim_set_current_buf(buffer.buf)
            end,
            50
          )
          return
        end
      end,
      {noremap = true, silent = true, nowait = true, buffer = buftable.buf}
    )
  end
end

function ModeManager:remove_buflist_jump_keymappings()
  local buftable = state.get_buffer_table()
  local buffers = state.get_buffer_list().buffers
  for _, buffer in ipairs(buffers) do
    pcall(
      vim.keymap.del,
      "n",
      buffer.key,
      {buffer = buftable.buf}
    )
  end
end

function ModeManager:add_buflist_select_keymappings()
  local buftable = state.get_buffer_table()
  local buffers = state.get_buffer_list().buffers
  vim.keymap.set(
    "n",
    "<cr>",
    function()
      local buf_key, _ = utils.get_buf_key_under_cursor(buftable.win, buffers)
      if buf_key ~= nil then
        state.get_floating_window():close()
        vim.api.nvim_set_current_buf(buf_key.buf)
      end
    end,
    {silent = true, remap = false, nowait = true, buffer = buftable.buf}
  )
  vim.keymap.set(
    "n",
    "H",
    function()
      local buf_key, _ = utils.get_buf_key_under_cursor(buftable.win, buffers)
      if buf_key ~= nil then
        vim.cmd("split")
        local split_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(split_win, buf_key.buf)
      end
    end,
    {silent = true, nowait = true, buffer = buftable.buf}
  )
  vim.keymap.set(
    "n",
    "V",
    function()
      local buf_key, _ = utils.get_buffer_key_under_cursor(buftable.win, buffers)
      if buf_key ~= nil then
        vim.cmd("vsplit")
        local split_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(split_win, buf_key.buf)
      end
    end,
    {silent = true, nowait = true, buffer = buftable.buf}
  )
end

function ModeManager:remove_buflist_select_keymappings()
  local buftable = state.get_buffer_table()
  pcall(vim.keymap.del, "n", "<cr>", {buffer = buftable.buf})
  pcall(vim.keymap.del, "n", "H", {buffer = buftable.buf})
  pcall(vim.keymap.del, "n", "V", {buffer = buftable.buf})
end

function ModeManager:add_jk_escape_hatch_keymappings()
  local buftable = state.get_buffer_table()
  vim.keymap.set(
    "n",
    "j",
    function()
      M.set_mode("jump")
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("j", true, false, true),
        "n",
        false
      )
    end,
    {silent = true, nowait = true, buffer = buftable.buf}
  )
  vim.keymap.set(
    "n",
    "k",
    function()
      M.set_mode("jump")
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("k", true, false, true),
        "n",
        false
      )
    end,
    {silent = true, nowait = true, buffer = buftable.buf}
  )
end

function ModeManager:remove_jk_escape_hatch_keymappings()
  local buftable = state.get_buffer_table()
  pcall(vim.keymap.del, "n", "j", {buffer = buftable.buf})
  pcall(vim.keymap.del, "n", "k", {buffer = buftable.buf})
end

function ModeManager:add_enter_delete_mode_keymapping()
  local buftable = state.get_buffer_table()
  vim.keymap.set(
    "n",
    "d",
    function()
      self:set_mode("delete")
      vim.o.operatorfunc = "v:lua.bufhopper_delete_operator"
      vim.keymap.set("o", "d", "$", {noremap = true, buffer = buftable.buf})
      return "g@"
    end,
    {expr = true, noremap = true, buffer = buftable.buf}
  )
end

function _G.bufhopper_delete_operator()
  local buftable = state.get_buffer_table()
  local start_mark = vim.api.nvim_buf_get_mark(buftable.buf, "[")
  local end_mark = vim.api.nvim_buf_get_mark(buftable.buf, "]")
  local buflist = state.get_buffer_list()
  local cursor_pos = vim.api.nvim_win_get_cursor(buftable.win)
  if start_mark[1] == end_mark[1] then
    buflist:remove_index(start_mark[1])
  else
    buflist:remove_index_range(start_mark[1], end_mark[1])
  end
  state.get_buffer_table():draw()
  if #buflist.buffers > 0 then
    if cursor_pos[1] > #buflist.buffers then
      cursor_pos[1] = cursor_pos[1] - 1
    end
    state.get_buffer_table():cursor_to_row(cursor_pos[1])
  end
  state.get_mode_manager():revert_mode()
end

function ModeManager:remove_enter_delete_mode_keymapping()
  local buftable = state.get_buffer_table()
  pcall(vim.keymap.del, "n", "d", {buffer = buftable.buf})
  pcall(vim.keymap.del, "o", "d", {buffer = buftable.buf})
end

function ModeManager:add_cancel_keymapping()
  local buftable = state.get_buffer_table()
  -- Cancel delete mode when the user presses escape.
  vim.keymap.set(
    {"o", "n"},
    "<esc>",
    function()
      self:revert_mode()
      return "<esc>"
    end,
    {expr = true, noremap = true, buffer = buftable.buf}
  )
end

function ModeManager:remove_cancel_keymapping()
  local buftable = state.get_buffer_table()
  pcall(vim.keymap.del, {"o", "n"}, "<esc>", {buffer = buftable.buf})
  pcall(vim.keymap.del, "o", "d", {buffer = buftable.buf})
end

M.ModeManager = ModeManager

return M
