local utils = require("bufhopper.utils")
local state = require("bufhopper.state")

---@alias BufhopperMode "open" | "jump" | "delete"

local M = {}

---@class BufhopperModeManager
---@field mode BufhopperMode | nil
---@field last_stable_mode BufhopperMode | nil
---@field create fun(): BufhopperModeManager
---@field set_mode fun(self: BufhopperModeManager, mode: BufhopperMode): nil
---@field revert_to_last_stable_mode fun(self: BufhopperModeManager): nil
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
  if mode == "delete" then
    if prev_mode == "jump" or prev_mode == "open" then
      self:remove_jump_mode_keymaps()
    end
    self:add_delete_mode_keymaps()
    self.last_stable_mode = prev_mode or "jump"
  elseif (mode == "jump" or mode == "open") then
    if prev_mode == "delete" then
      self:remove_delete_mode_keymaps()
    end
    self:add_jump_mode_keymaps()
  end
  self.mode = mode
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

function ModeManager:revert_to_last_stable_mode()
  self:set_mode(self.last_stable_mode)
end

function ModeManager:add_jump_mode_keymaps()
  local buftable = state.get_buffer_table()
  local buffers = state.get_buffer_list().buffers

  -- Add buffer specific jump keymaps.
  for i, buffer in ipairs(buffers) do
    if buffer.key ~= nil then
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
  -- Add buffer selection keymaps.
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
  -- Add enter delete mode keymaps.
  vim.keymap.set(
    "n",
    "d",
    function()
      self:set_mode("delete")
      vim.o.operatorfunc = "v:lua.bufhopper_delete_operator"
      -- Handle "dd" keymap.
      vim.keymap.set("o", "d", "$", {noremap = true, buffer = buftable.buf})
      return "g@"
    end,
    {expr = true, noremap = true, buffer = buftable.buf}
  )
end

function _G.bufhopper_delete_operator()
  local buftable = state.get_buffer_table()
  local buflist = state.get_buffer_list()
  local start_mark = vim.api.nvim_buf_get_mark(buftable.buf, "[")
  local end_mark = vim.api.nvim_buf_get_mark(buftable.buf, "]")
  local cursor_pos = vim.api.nvim_win_get_cursor(buftable.win)
  if start_mark[1] == end_mark[1] then
    buflist:remove_at_index(start_mark[1])
  else
    buflist:remove_in_index_range(start_mark[1], end_mark[1])
  end
  buflist:populate()
  buftable:draw()
  if #buflist.buffers > 0 then
    if cursor_pos[1] > #buflist.buffers then
      cursor_pos[1] = cursor_pos[1] - 1
    end
    state.get_buffer_table():cursor_to_row(cursor_pos[1])
  end
  state.get_mode_manager():revert_to_last_stable_mode()
end


function ModeManager:add_delete_mode_keymaps()
  local buftable = state.get_buffer_table()
  -- Cancel delete mode when the user presses escape.
  vim.keymap.set(
    {"o", "n"},
    "<esc>",
    function()
      self:revert_to_last_stable_mode()
      return "<esc>"
    end,
    {expr = true, noremap = true, buffer = buftable.buf}
  )
end

function ModeManager:remove_jump_mode_keymaps()
  local buftable = state.get_buffer_table()
  local buffers = state.get_buffer_list().buffers

  -- Remove buffer specific jump keymaps.
  for _, buffer in ipairs(buffers) do
    if buffer.key ~= nil then
      pcall(
        vim.keymap.del,
        "n",
        buffer.key,
        {buffer = buftable.buf}
      )
    end
  end
  -- Remove buffer selection keymaps.
  pcall(vim.keymap.del, "n", "<cr>", {buffer = buftable.buf})
  pcall(vim.keymap.del, "n", "H", {buffer = buftable.buf})
  pcall(vim.keymap.del, "n", "V", {buffer = buftable.buf})
  -- Remove enter delete mode keymaps.
  pcall(vim.keymap.del, "n", "d", {buffer = buftable.buf})
  pcall(vim.keymap.del, "o", "d", {buffer = buftable.buf})
end

function ModeManager:remove_delete_mode_keymaps()
  local buftable = state.get_buffer_table()
  pcall(vim.keymap.del, {"o", "n"}, "<esc>", {buffer = buftable.buf})
  pcall(vim.keymap.del, "o", "d", {buffer = buftable.buf})
end

M.ModeManager = ModeManager

return M
