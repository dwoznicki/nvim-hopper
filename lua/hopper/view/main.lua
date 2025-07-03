local utils = require("hopper.utils")
local quickfile = require("hopper.quickfile")

local ns_id = vim.api.nvim_create_namespace("hopper.MainFloat")
local footer_ns_id = vim.api.nvim_create_namespace("hopper.MainFloatFooter")
--TODO: Make this configurable.
local num_chars = 2

local M = {}

---@alias hopper.KeymapFileTree table<string, hopper.KeymapFileNode>
---@alias hopper.KeymapFileNode hopper.KeymapFileTree | hopper.FileMapping

---@class hopper.MainFloat
---@field project string
---@field files hopper.FileMapping[]
---@field keymap_file_tree hopper.KeymapFileTree
---@field filtered_files hopper.FileMapping[]
---@field buf integer
---@field win integer
---@field win_width integer
---@field footer_buf integer
---@field footer_win integer
---@field prior_buf integer
local MainFloat = {}
MainFloat.__index = MainFloat
M.MainFloat = MainFloat

---@return hopper.MainFloat
function MainFloat._new()
  local float = {}
  setmetatable(float, MainFloat)
  MainFloat._reset(float)
  return float
end

---@param float hopper.MainFloat
function MainFloat._reset(float)
  float.project = ""
  float.files = {}
  float.keymap_file_tree = {}
  float.filtered_files = {}
  float.buf = -1
  float.win = -1
  float.win_width = -1
  float.footer_buf = -1
  float.footer_win = -1
  float.prior_buf = -1
end

---@class hopper.OpenMainFloatOptions
---@field project string | nil
---@field prior_buf integer | nil

---@param opts? hopper.OpenMainFloatOptions
function MainFloat:open(opts)
  opts = opts or {}
  self.project = opts.project
  self.prior_buf = opts.prior_buf or vim.api.nvim_get_current_buf()

  local ui = vim.api.nvim_list_uis()[1]
  local win_width, win_height = utils.get_win_dimensions()
  self.win_width = win_width

  local datastore = require("hopper.db").datastore()
  local files = datastore:list_files(self.project)
  self:_set_files(files)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "prompt", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("buflisted", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "hopperfloat", {buf = buf})
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = 3,
    col = math.floor((ui.width - win_width) * 0.5),
    focusable = true,
    title = " Hopper ",
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
  local win = vim.api.nvim_open_win(buf, true, win_config)

  local footer_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = footer_buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = footer_buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = footer_buf})
  vim.api.nvim_buf_set_lines(footer_buf, 0, -1, false, {""})
  ---@type vim.api.keyset.win_config
  local footer_win_config = {
    style = "minimal",
    relative = "editor",
    width = win_config.width,
    height = 1,
    row = win_config.row + win_config.height,
    col = win_config.col + 1,
    focusable = false,
    border = "none",
    zindex = 51, -- Just enough to site on top of the main window.
  }
  local footer_win = vim.api.nvim_open_win(footer_buf, false, footer_win_config)
  -- vim.api.nvim_set_option_value("winhighlight", "Normal:hopper.hl.FloatFooter", {win = footer_win})

  self.buf = buf
  self.win = win
  self.footer_buf = footer_buf
  self.footer_win = footer_win

  self:_attach_event_handlers()

  self:draw()
  self:draw_footer()
end

function MainFloat:draw()
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
    local path = quickfile.truncate_path(file.path, self.win_width - 2)
    local keymap_indexes = quickfile.keymap_location_in_path(path, file.keymap, {missing_behavior = "nearby"})
    local path_line = quickfile.highlight_path_virtual_text(path, file.keymap, keymap_indexes, {next_key_index = next_key_index})
    table.insert(virtual_lines, path_line)
  end

  vim.api.nvim_buf_set_extmark(self.buf, ns_id, 0, 0, {
    virt_lines = virtual_lines,
    virt_lines_above = false,
    virt_lines_leftcol = false,
  })
end

function MainFloat:draw_footer()
  vim.api.nvim_buf_clear_namespace(self.footer_buf, footer_ns_id, 0, -1)
  local help_line = {{" "}} ---@type string[][]
  local curr_mode = vim.api.nvim_get_mode().mode
  if curr_mode == "n" then
    table.insert(help_line, {"n", "Function"})
    table.insert(help_line, {" New keymap"})
  else
    table.insert(help_line, {"n New keymap", "Comment"})
  end
  vim.api.nvim_buf_set_extmark(self.footer_buf, footer_ns_id, 0, 0, {
    virt_text = help_line,
  })
end

function MainFloat:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  if vim.api.nvim_win_is_valid(self.footer_win) then
    vim.api.nvim_win_close(self.footer_win, true)
  end
  MainFloat._reset(self)
end

---@param files hopper.FileMapping[]
function MainFloat:_set_files(files)
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

function MainFloat:_attach_event_handlers()
  local buf = self.buf

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

  vim.api.nvim_create_autocmd("ModeChanged", {
    buffer = buf,
    callback = function()
      self:draw_footer()
    end,
  })

  -- Close on esc keypress.
  vim.keymap.set(
    "n",
    "<esc>",
    function()
      self:close()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  -- Open new keymap view on n keypress.
  vim.keymap.set(
    "n",
    "n",
    function()
      local path = require("hopper.filepath").get_path_from_project_root(vim.api.nvim_buf_get_name(self.prior_buf))
      local options = {
        project = self.project,
        prior_buf = self.prior_buf,
      }
      require("hopper.view.keymap_float").float():open(
        path,
        {
          project = self.project,
          go_back = function()
            self:open(options)
          end,
        }
      )
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )

  vim.api.nvim_create_autocmd({"BufWinLeave", "WinLeave"}, {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        self:close()
      end)
    end,
  })
end

local _float = nil ---@type hopper.MainFloat | nil

---@return hopper.MainFloat
function M.float()
  if _float == nil then
    _float = MainFloat._new()
  end
  return _float
end

return M
