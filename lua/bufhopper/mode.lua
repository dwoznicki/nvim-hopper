local Buflist = require("bufhopper.buflist")
local Float = require("bufhopper.float")

local M = {}

---@type BufhopperModeState
M.state = {
  mode = nil
}

local function add_buflist_jump_keymappings()
  local buf_keys = Buflist.state.buf_keys
  local win = Float.get_win()
  local buf = Buflist.get_buf()
  for i, buf_key in ipairs(buf_keys) do
    vim.keymap.set(
      "n",
      buf_key.key,
      function()
        vim.api.nvim_win_set_cursor(win, {i, 0})
        if M.state.mode == "open" then
          vim.defer_fn(
            function()
              M.close()
              vim.api.nvim_set_current_buf(buf_key.buf)
            end,
            50
          )
          return
        end
      end,
      {noremap = true, silent = true, nowait = true, buffer = buf}
    )
  end
end

local function remove_buflist_jump_keymappings()
  local buf_keys = Buflist.state.buf_keys
  local buf = Buflist.get_buf()
  for _, buf_key in buf_keys do
    pcall(
      vim.keymap.del,
      "n",
      buf_key.key,
      {buffer = buf}
    )
  end
end

local function add_buflist_select_keymappings()
  local buf = Buflist.get_buf()
  vim.keymap.set(
    "n",
    "<cr>",
    function()
      local buf_key, _ = Buflist.get_buffer_key_under_cursor()
      if buf_key ~= nil then
        M.close()
        vim.api.nvim_set_current_buf(buf_key.buf)
      end
    end,
    {silent = true, remap = false, nowait = true, buffer = buf}
  )
  vim.keymap.set(
    "n",
    "H",
    function()
      local buf_key, _ = Buflist.get_buffer_key_under_cursor()
      if buf_key ~= nil then
        vim.cmd("split")
        local split_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(split_win, buf_key.buf)
      end
    end,
    {silent = true, nowait = true, buffer = buf}
  )
  vim.keymap.set(
    "n",
    "V",
    function()
      local buf_key, _ = Buflist.get_buffer_key_under_cursor()
      if buf_key ~= nil then
        vim.cmd("vsplit")
        local split_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(split_win, buf_key.buf)
      end
    end,
    {silent = true, nowait = true, buffer = buf}
  )
end

local function remove_buflist_select_keymappings()
  local buf = Buflist.get_buf()
  pcall(vim.keymap.del, "n", "<cr>", {buffer = buf})
  pcall(vim.keymap.del, "n", "H", {buffer = buf})
  pcall(vim.keymap.del, "n", "V", {buffer = buf})
end

local function add_jk_escape_hatch_keymappings()
  local buf = Buflist.get_buf()
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
    {silent = true, nowait = true, buffer = buf}
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
    {silent = true, nowait = true, buffer = buf}
  )
end

local function remove_jk_escape_hatch_keymappings()
  local buf = Buflist.get_buf()
  pcall(vim.keymap.del, "n", "j", {buffer = buf})
  pcall(vim.keymap.del, "n", "k", {buffer = buf})
end

local function add_enter_delete_mode_keymapping()
  local buf = Buflist.get_buf()
  vim.keymap.set(
    "n",
    "d",
    function()
      M.set_mode("delete")
      vim.o.operatorfunc = "v:lua.BufhopperDeleteOperator"
      return "g@"
    end,
    {expr = true, noremap = true, buffer = buf}
  )
end

function _G.BufhopperDeleteOperator()
  local buf = vim.api.nvim_get_current_buf()
  local start_mark = vim.api.nvim_buf_get_mark(buf, "[")
  local end_mark   = vim.api.nvim_buf_get_mark(buf, "]")
  -- local is_linewise = (start_mark[2] == 1) and (end_mark[2] == 0 or end_mark[2] >= #end_line_text)
  -- vim.print(is_linewise)
  local is_linewise = start_mark[1] ~= end_mark[1]
  vim.print(start_mark, end_mark, is_linewise, vim.v.operator)
end

local function remove_enter_delete_mode_keymapping()
  local buf = Buflist.get_buf()
  pcall(vim.keymap.del, "n", "d", {buffer = buf})
end

M.lifecycle = {
  ---@type BufhopperModeLifecycle
  open = {
    setup = function()
      add_buflist_jump_keymappings()
      add_jk_escape_hatch_keymappings()
      add_enter_delete_mode_keymapping()
    end,
    teardown = function()
      remove_buflist_jump_keymappings()
      remove_jk_escape_hatch_keymappings()
      remove_enter_delete_mode_keymapping()
    end,
  },
  ---@type BufhopperModeLifecycle
  jump = {
    setup = function()
      add_buflist_jump_keymappings()
      add_buflist_select_keymappings()
      add_enter_delete_mode_keymapping()
    end,
    teardown = function()
      remove_buflist_jump_keymappings()
      remove_buflist_select_keymappings()
      remove_enter_delete_mode_keymapping()
    end,
  },
  ---@type BufhopperModeLifecycle
  delete = {
    setup = function()
    end,
    teardown = function()
    end,
  },
}

---@param mode mode
function M.set_mode(mode)
  if mode == M.state.mode then
    return
  end
  if M.state.mode ~= nil then
    M.lifecycle[M.state.mode].teardown()
  end
  M.state.mode = mode
  M.lifecycle[mode].setup()

  if mode ~= "jump" then
    vim.keymap.set(
      "n",
      "<esc>",
      function()
        M.set_mode("jump")
      end,
      {silent = true, nowait = true, buffer = Buflist.get_buf()}
    )
  end
end

return M
