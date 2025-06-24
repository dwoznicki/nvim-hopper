local utils = require("hopper.utils")
local quickfile = require("hopper.quickfile")

local ns_id = vim.api.nvim_create_namespace("hopper.FilesFloatingWindow")
--TODO: Make this configurable.
local num_chars = 2

local M = {}

---@alias hopper.KeymapFileTree table<string, hopper.KeymapFileNode>
---@alias hopper.KeymapFileNode hopper.KeymapFileTree | hopper.FileMapping

---@class hopper.FilesFloatingWindow
---@field project string
---@field files hopper.FileMapping[]
---@field keymap_file_tree hopper.KeymapFileTree
---@field filtered_files hopper.FileMapping[]
---@field buf integer
---@field win integer
---@field win_width integer
local FilesFloatingWindow = {}
FilesFloatingWindow.__index = FilesFloatingWindow
M.FilesFloatingWindow = FilesFloatingWindow

---@return hopper.FilesFloatingWindow
function FilesFloatingWindow._new()
  local float = {}
  setmetatable(float, FilesFloatingWindow)
  FilesFloatingWindow._reset(float)
  return float
end

---@param float hopper.FilesFloatingWindow
function FilesFloatingWindow._reset(float)
  float.project = ""
  float.files = {}
  float.keymap_file_tree = {}
  float.filtered_files = {}
  float.buf = -1
  float.win = -1
  float.win_width = -1
end

---@param project string
---@param files hopper.FileMapping[]
function FilesFloatingWindow:open(project, files)
  local ui = vim.api.nvim_list_uis()[1]
  local win_width, win_height = utils.get_win_dimensions()
  self.win_width = win_width

  self.project = project
  self:_set_files(files)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "prompt", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("buflisted", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "HopperFilesFloat", {buf = buf})
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = 3,
    col = math.floor((ui.width - win_width) * 0.5),
    focusable = true,
    title = " Files ",
    title_pos = "center",
    border = "rounded",
  }
  -- Don't show the prompt text.
  vim.fn.prompt_setprompt(buf, "")
  -- Start in insert mode so user can immediately start typing.
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = buf,
    callback = function()
      vim.cmd("startinsert")
    end,
  })
  -- -- If there is an existing mapping, pre-populate it.
  -- -- Otherwise, start in insert mode so user can immediately start typing.
  -- if existing_keymap then
  --   vim.api.nvim_buf_set_lines(buf, 0, 1, false, {existing_keymap})
  -- else
  --   vim.api.nvim_create_autocmd("BufEnter", {
  --     buffer = buf,
  --     callback = function()
  --       vim.cmd("startinsert")
  --     end,
  --   })
  -- end
  local win = vim.api.nvim_open_win(buf, true, win_config)
  self.buf = buf
  self.win = win

  self:_attach_event_handlers()

  self:draw()
end

-- function FilesFloatingWindow:attach_keymaps()
--   for _, file in ipairs(self.visible_files) do
--   end
-- end

function FilesFloatingWindow:draw()
  vim.api.nvim_buf_clear_namespace(self.buf, ns_id, 0, -1) -- clear highlights

  local value = vim.api.nvim_buf_get_lines(self.buf, 0, 1, false)[1] or ""
  local used = string.len(value)
  vim.api.nvim_buf_set_extmark(self.buf, ns_id, 0, 0, {
    virt_text = {
      {string.format("%d/%d", used, num_chars), "Comment"}
    },
    virt_text_pos = "right_align",
  })

  local virtual_lines = {} ---@type string[][][]

  local next_key_index = used + 1
  for _, file in ipairs(self.filtered_files) do
    local keymap_indexes = quickfile.keymap_location_in_path(file.path, file.keymap, {missing_behavior = "nearby"})
    local path_line = quickfile.highlight_path_virtual_text(file.path, file.keymap, keymap_indexes, {next_key_index = next_key_index})
    table.insert(virtual_lines, path_line)
  end

  vim.api.nvim_buf_set_extmark(self.buf, ns_id, 0, 0, {
    virt_lines = virtual_lines,
    virt_lines_above = false,
    virt_lines_leftcol = false,
  })
end

function FilesFloatingWindow:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  FilesFloatingWindow._reset(self)
end

---@param files hopper.FileMapping[]
function FilesFloatingWindow:_set_files(files)
  local tree = {} ---@type hopper.KeymapFileTree
  for _, file in ipairs(files) do
    local node = tree ---@type hopper.KeymapFileNode | hopper.KeymapFileTree
    for i = 1, string.len(file.keymap) do
      local key = string.sub(file.keymap, i, i)
      if node[key] == nil then
        node[key] = {} ---@type hopper.KeymapFileTree
      end
      if i == string.len(file.keymap) then
        node[key] = file
      end
      node = node[key]
    end
  end
  self.files = files
  self.filtered_files = files
  self.keymap_file_tree = tree
end

function FilesFloatingWindow:_attach_event_handlers()
  local buf = self.buf

  -- vim.keymap.set(
  --   {"i", "n"},
  --   "<cr>",
  --   function()
  --     self:confirm()
  --   end,
  --   {noremap = true, silent = true, nowait = true, buffer = buf}
  -- )

  -- -- Close on "q" keypress.
  -- vim.keymap.set(
  --   "n",
  --   "q",
  --   function()
  --     self:close()
  --   end,
  --   {noremap = true, silent = true, nowait = true, buffer = buf}
  -- )

  -- -- prevent the user ever leaving insert mode:
  -- vim.api.nvim_create_autocmd("InsertLeave", {
  --   buffer = buf,
  --   callback = function()
  --     local value = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
  --     if string.len(value) > 0 then
  --       vim.api.nvim_buf_set_lines(buf, 0, 1, false, {""})
  --     end
  --   end,
  -- })

  vim.api.nvim_create_autocmd({"TextChangedI", "TextChanged"}, {
    buffer = buf,
    callback = function()
      -- Clear the `modified` flag for prompt.
      vim.bo[buf].modified = false
      local value = utils.clamp_buffer_value(buf, num_chars)
      vim.print(value)
      if string.len(value) < 1 then
        self.filtered_files = self.files
        self:draw()
        return
      end
      local selected = vim.tbl_get(self.keymap_file_tree, unpack(vim.split(value, ""))) ---@type hopper.FileMapping | hopper.KeymapFileTree | nil
      if selected == nil then
        self.filtered_files = {}
        self:draw()
        return
      end
      if selected.path then
        vim.print(selected)
        self:draw()
      else
        local filtered_files = {} ---@type hopper.FileMapping[]
        local stack = vim.tbl_values(selected) ---@type (hopper.FileMapping | hopper.KeymapFileNode)[]
        while #stack > 0 do
          local item = table.remove(stack, 1) ---@type hopper.FileMapping | hopper.KeymapFileNode
          if item.path then
            table.insert(filtered_files, item)
          else
            table.insert(stack, item)
          end
        end
        self.filtered_files = filtered_files
        self:draw()
      end
    end,
  })

  -- Close on "<esc>" keypress.
  vim.keymap.set(
    "n",
    "<esc>",
    function()
      self:close()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )

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
end

local _float = nil ---@type hopper.FilesFloatingWindow | nil

---@return hopper.FilesFloatingWindow
function M.float()
  if _float == nil then
    _float = FilesFloatingWindow._new()
  end
  return _float
end

return M
