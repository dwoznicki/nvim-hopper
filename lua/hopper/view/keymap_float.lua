local utils = require("hopper.utils")
local quickfile = require("hopper.quickfile")

---@alias hopper.HighlightLocation {name: string, row: integer, col_start: integer, col_end: integer}

local ns_id = vim.api.nvim_create_namespace("hopper.KeymapFloatingWindow")

local M = {}

---@class hopper.KeymapFloatingWindow
---@field project string
---@field path string
---@field keymap string
---@field buf integer
---@field win integer
---@field win_width integer
local KeymapFloatingWindow = {}
KeymapFloatingWindow.__index = KeymapFloatingWindow
M.KeymapFloatingWindow = KeymapFloatingWindow

---@return hopper.KeymapFloatingWindow
function KeymapFloatingWindow._new()
  local float = {}
  setmetatable(float, KeymapFloatingWindow)
  KeymapFloatingWindow._reset(float)
  return float
end

---@param float hopper.KeymapFloatingWindow
function KeymapFloatingWindow._reset(float)
  float.project = ""
  float.path = ""
  float.keymap = ""
  float.buf = -1
  float.win = -1
  float.win_width = -1
end

---@param project string
---@param path string
---@param existing_keymap string | nil
function KeymapFloatingWindow:open(project, path, existing_keymap)
  local ui = vim.api.nvim_list_uis()[1]
  local win_width, _ = utils.get_win_dimensions()
  self.win_width = win_width

  self.project = project
  self.path = quickfile.truncate_path(path, win_width)
  self.keymap = existing_keymap or ""

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "prompt", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("buflisted", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "HopperKeymapFloat", {buf = buf})
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = 2,
    row = 3,
    col = math.floor((ui.width - win_width) * 0.5),
    -- border = "none",
    focusable = true,
    title = " Enter a keymap ",
    title_pos = "center",
    border = "rounded",
  }
  -- Don't show the prompt text.
  vim.fn.prompt_setprompt(buf, "")
  -- Start in insert mode.
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = buf,
    callback = function()
      vim.cmd("startinsert")
    end,
  })
  local win = vim.api.nvim_open_win(buf, true, win_config)
  self.buf = buf
  self.win = win

  self:_attach_event_handlers()

  self:draw()
end

function KeymapFloatingWindow:draw()

  vim.api.nvim_buf_clear_namespace(self.buf, ns_id, 0, -1) -- clear highlights

  local value = vim.api.nvim_buf_get_lines(self.buf, 0, 1, false)[1] or ""
  local used = string.len(value)
  local max_chars = 2
  vim.api.nvim_buf_set_extmark(self.buf, ns_id, 0, 0, {
    virt_text = {
      {string.format("%d/%d", used, max_chars), "Comment"}
    },
    virt_text_pos = "right_align",
  })

  local keymap_indexes = quickfile.keymap_location_in_path(self.path, self.keymap, {missing_behavior = "nearby"})
  local virtual_text = quickfile.highlight_path_virtual_text(self.path, self.keymap, keymap_indexes)
  vim.print(virtual_text)

  vim.api.nvim_buf_set_extmark(self.buf, ns_id, 0, 0, {
    virt_lines = {
      virtual_text,
      -- {
      --   {self.path, "hopper.hl.SecondaryText"},
      -- },
    },
    virt_lines_above = false,
    virt_lines_leftcol = false,
  })
end

function KeymapFloatingWindow:confirm()
  local datastore = require("hopper.db").datastore()
  datastore:set_quick_file(self.project, self.path, self.keymap)
end

function KeymapFloatingWindow:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  -- if vim.api.nvim_win_is_valid(self.helper_win) then
  --   vim.api.nvim_win_close(self.helper_win, true)
  -- end
  -- if vim.api.nvim_win_is_valid(self.container_win) then
  --   vim.api.nvim_win_close(self.container_win, true)
  -- end
  KeymapFloatingWindow._reset(self)
end

-- ---@param ui any
-- ---@param win_width integer
-- ---@return integer buf, integer win
-- function KeymapFloatingWindow._open_container(ui, win_width)
--   local buf = vim.api.nvim_create_buf(false, true)
--   vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
--   vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
--   vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
--   ---@type vim.api.keyset.win_config
--   local win_config = {
--     style = "minimal",
--     relative = "editor",
--     width = win_width,
--     height = 2,
--     row = 3,
--     col = math.floor((ui.width - win_width) * 0.5),
--     -- border = "none",
--     focusable = false,
--     title = " Enter a keymap ",
--     title_pos = "center",
--     border = "rounded",
--   }
--   local win = vim.api.nvim_open_win(buf, false, win_config)
--   return buf, win
-- end

-- ---@param container_win integer
-- ---@param win_width integer
-- ---@return integer buf, integer win
-- function KeymapFloatingWindow._open_input(container_win, win_width)
--   local buf = vim.api.nvim_create_buf(false, true)
--   vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
--   vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
--   vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
--   vim.api.nvim_set_option_value("filetype", "HopperKeymapFloat", {buf = buf})
--   ---@type vim.api.keyset.win_config
--   local win_config = {
--     style = "minimal",
--     relative = "win",
--     win = container_win,
--     width = win_width,
--     -- height = win_height - 1, -- space for status line
--     height = 2,
--     row = 0,
--     col = 0,
--     border = "none",
--     focusable = true,
--   }
--   -- Start in insert mode.
--   vim.api.nvim_create_autocmd("BufEnter", {
--     buffer = buf,
--     callback = function()
--       vim.cmd("startinsert")
--     end,
--   })
--   local win = vim.api.nvim_open_win(buf, true, win_config)
--   return buf, win
-- end

-- ---@param container_win integer
-- ---@param win_width integer
-- ---@return integer buf, integer win
-- function KeymapFloatingWindow._open_helper(container_win, win_width)
--   local buf = vim.api.nvim_create_buf(false, true)
--   vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
--   vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
--   vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
--   vim.api.nvim_set_option_value("modifiable", false, {buf = buf})
--   ---@type vim.api.keyset.win_config
--   local win_config = {
--     style = "minimal",
--     relative = "win",
--     win = container_win,
--     width = win_width,
--     height = 1,
--     row = 1,
--     col = 0,
--     border = "none",
--     focusable = false,
--   }
--   local win = vim.api.nvim_open_win(buf, false, win_config)
--   return buf, win
-- end

function KeymapFloatingWindow:_attach_event_handlers()
  local buf = self.buf
  vim.keymap.set(
    {"i", "n"},
    "<cr>",
    function()
      self:confirm()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  -- Close on "q" keypress.
  vim.keymap.set(
    "n",
    "q",
    function()
      self:close()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  -- Close on "<esc>" keypress.
  vim.keymap.set(
    "n",
    "<esc>",
    function()
      self:close()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )

  vim.api.nvim_create_autocmd({"TextChangedI", "TextChanged"}, {
    buffer = buf,
    callback = function()
      local value = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
      -- local value = vim.fn.prompt_getprompt(buf)
      if string.len(value) > 2 then
        value = value:sub(1, 2)
        vim.api.nvim_buf_set_lines(buf, 0, 1, false, {value})
      end
      self.keymap = value
      self:draw()
      -- vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
      -- vim.api.nvim_buf_add_highlight(bufnr, ns,
      --   'PmenuSel', 0, #line, -1)
    end,
  })

  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      self:close()
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      self:close()
    end,
  })

  -- require("bufhopper.integrations").clear_whichkey(buf)

  -- Close the float when the cursor leaves.
  -- vim.api.nvim_create_autocmd("WinLeave", {
  --   buffer = buf,
  --   once = true,
  --   callback = function()
  --     state.get_floating_window():close()
  --   end,
  -- })
  -- vim.api.nvim_create_autocmd("BufWipeout", {
  --   buffer = buf,
  --   once = true,
  --   callback = function()
  --     state.get_floating_window():close()
  --   end,
  -- })
end

local instance = nil ---@type hopper.KeymapFloatingWindow | nil
---@return hopper.KeymapFloatingWindow
function M.instance()
  if instance == nil then
    instance = KeymapFloatingWindow._new()
  end
  return instance
end

return M
