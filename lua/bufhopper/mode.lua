local utils = require("bufhopper.utils")
local state = require("bufhopper.state")

---@alias BufhopperMode "open" | "jump" | "delete"

local M = {}

---@class BufhopperModeManager
---@field mode BufhopperMode | nil
---@field new fun(): BufhopperModeManager
---@field set_mode fun(self: BufhopperModeManager, mode: BufhopperMode): nil
---@field setup fun(self: BufhopperModeManager): nil
---@field teardown fun(self: BufhopperModeManager): nil
local ModeManager = {}
ModeManager.__index = ModeManager

function ModeManager.new()
  local mode_manager = {}
  setmetatable(mode_manager, ModeManager)
  vim.api.nvim_create_autocmd("User", {
    pattern = "BufhopperModeChanged",
    callback = function()
      vim.schedule(
        function()
          state.get_statline():draw()
        end
      )
    end,
  })
  return mode_manager
end

function ModeManager:set_mode(mode)
  self:teardown()
  self.mode = mode
  self:setup()
  vim.api.nvim_exec_autocmds("User", {
    pattern = "BufhopperModeChanged",
    data = {
      mode = mode,
    },
  })

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
  end
end

function ModeManager:add_buflist_jump_keymappings()
  local buflist = state.get_buflist()
  for i, buf_key in ipairs(buflist.buf_keys) do
    vim.keymap.set(
      "n",
      buf_key.key,
      function()
        vim.api.nvim_win_set_cursor(buflist.win, {i, 0})
        if self.mode == "open" then
          vim.defer_fn(
            function()
              state.get_float():close()
              vim.api.nvim_set_current_buf(buf_key.buf)
            end,
            50
          )
          return
        end
      end,
      {noremap = true, silent = true, nowait = true, buffer = buflist.buf}
    )
  end
end

function ModeManager:remove_buflist_jump_keymappings()
  local buflist = state.get_buflist()
  for _, buf_key in ipairs(buflist.buf_keys) do
    pcall(
      vim.keymap.del,
      "n",
      buf_key.key,
      {buffer = buflist.buf}
    )
  end
end

function ModeManager:add_buflist_select_keymappings()
  local buflist = state.get_buflist()
  vim.keymap.set(
    "n",
    "<cr>",
    function()
      local buf_key, _ = utils.get_buf_key_under_cursor(buflist.win, buflist.buf_keys)
      if buf_key ~= nil then
        state.get_float():close()
        vim.api.nvim_set_current_buf(buf_key.buf)
      end
    end,
    {silent = true, remap = false, nowait = true, buffer = buflist.buf}
  )
  vim.keymap.set(
    "n",
    "H",
    function()
      local buf_key, _ = utils.get_buf_key_under_cursor(buflist.win, buflist.buf_keys)
      if buf_key ~= nil then
        vim.cmd("split")
        local split_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(split_win, buf_key.buf)
      end
    end,
    {silent = true, nowait = true, buffer = buflist.buf}
  )
  vim.keymap.set(
    "n",
    "V",
    function()
      local buf_key, _ = utils.get_buffer_key_under_cursor(buflist.win, buflist.buf_keys)
      if buf_key ~= nil then
        vim.cmd("vsplit")
        local split_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(split_win, buf_key.buf)
      end
    end,
    {silent = true, nowait = true, buffer = buflist.buf}
  )
end

function ModeManager:remove_buflist_select_keymappings()
  local buflist = state.get_buflist()
  pcall(vim.keymap.del, "n", "<cr>", {buffer = buflist.buf})
  pcall(vim.keymap.del, "n", "H", {buffer = buflist.buf})
  pcall(vim.keymap.del, "n", "V", {buffer = buflist.buf})
end

function ModeManager:add_jk_escape_hatch_keymappings()
  local buflist = state.get_buflist()
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
    {silent = true, nowait = true, buffer = buflist.buf}
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
    {silent = true, nowait = true, buffer = buflist.buf}
  )
end

function ModeManager:remove_jk_escape_hatch_keymappings()
  local buflist = state.get_buflist()
  pcall(vim.keymap.del, "n", "j", {buffer = buflist.buf})
  pcall(vim.keymap.del, "n", "k", {buffer = buflist.buf})
end

function ModeManager:add_enter_delete_mode_keymapping()
  local buflist = state.get_buflist()
  vim.keymap.set(
    "n",
    "d",
    function()
      self:set_mode("delete")
      vim.o.operatorfunc = "v:lua.bufhopper_delete_operator"
      return "g@"
    end,
    {expr = true, noremap = true, buffer = buflist.buf}
  )
end

function _G.bufhopper_delete_operator()
  local buf = vim.api.nvim_get_current_buf()
  local start_mark = vim.api.nvim_buf_get_mark(buf, "[")
  local end_mark   = vim.api.nvim_buf_get_mark(buf, "]")
  -- local is_linewise = (start_mark[2] == 1) and (end_mark[2] == 0 or end_mark[2] >= #end_line_text)
  -- vim.print(is_linewise)
  local is_linewise = start_mark[1] ~= end_mark[1]
  vim.print(start_mark, end_mark, is_linewise, vim.v.operator)
end

function ModeManager:remove_enter_delete_mode_keymapping()
  local buflist = state.get_buflist()
  pcall(vim.keymap.del, "n", "d", {buffer = buflist.buf})
end

M.ModeManager = ModeManager

return M
