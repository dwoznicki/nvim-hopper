local utils = require("hopper.utils")
local keymaps = require("hopper.keymaps")
local projects = require("hopper.projects")
local options = require("hopper.options")

local M = {}

---@alias hopper.KeymapFileTree table<string, hopper.KeymapFileNode>
---@alias hopper.KeymapFileNode hopper.KeymapFileTree | hopper.FileMapping

---@class hopper.Jumper
---@field project hopper.Project | nil
---@field files hopper.FileMapping[]
---@field is_open boolean
---@field keymap_file_tree hopper.KeymapFileTree
---@field filtered_files hopper.FileMapping[]
---@field buf integer
---@field win integer
---@field win_width integer
---@field footer_buf integer
---@field footer_win integer
---@field prior_buf integer
---@field keymap_length integer
---@field open_cmd string | nil
local Jumper = {}
Jumper.__index = Jumper
M.Jumper = Jumper

Jumper.ns = vim.api.nvim_create_namespace("hopper.Jumper")
Jumper.footer_ns = vim.api.nvim_create_namespace("hopper.JumperFooter")

---@return hopper.Jumper
function Jumper._new()
  local float = {}
  setmetatable(float, Jumper)
  Jumper._reset(float)
  return float
end

---@param float hopper.Jumper
function Jumper._reset(float)
  float.project = nil
  float.files = {}
  float.is_open = false
  float.keymap_file_tree = {}
  float.filtered_files = {}
  float.buf = -1
  float.win = -1
  float.win_width = -1
  float.footer_buf = -1
  float.footer_win = -1
  float.prior_buf = -1
  float.keymap_length = -1
  float.open_cmd = nil
end

---@class hopper.OpenJumperOptions
---@field project hopper.Project | string | nil
---@field prior_buf integer | nil
---@field keymap_length integer | nil
---@field open_cmd string | nil
---@field width integer | decimal | nil
---@field height integer | decimal | nil

---@param opts? hopper.OpenJumperOptions
function Jumper:open(opts)
  opts = opts or {}
  local full_options = options.options()
  self.project = projects.ensure_project(opts.project)
  self.prior_buf = opts.prior_buf or vim.api.nvim_get_current_buf()
  self.keymap_length = opts.keymap_length or full_options.keymapping.length
  self.open_cmd = opts.open_cmd or full_options.keymapping.default_open_cmd
  if self.open_cmd ~= nil and string.len(self.open_cmd) < 1 then
    vim.notify_once(string.format('Open command "%s" is invalid.', self.open_cmd), vim.log.levels.WARN)
  end

  local ui = vim.api.nvim_list_uis()[1]
  local opts_width = opts.width or full_options.float.width
  local opts_height = opts.height or full_options.float.height
  local win_width, win_height = utils.get_win_dimensions(opts_width, opts_height)
  self.win_width = win_width

  local datastore = require("hopper.db").datastore()
  local files = datastore:list_files(self.project.name, self.keymap_length)
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
    zindex = 51, -- Just enough to site on top of the jumper window.
  }
  local footer_win = vim.api.nvim_open_win(footer_buf, false, footer_win_config)

  self.buf = buf
  self.win = win
  self.footer_buf = footer_buf
  self.footer_win = footer_win
  self.is_open = true

  self:_attach_event_handlers()

  self:draw()
  self:draw_footer()
end

function Jumper:draw()
  vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1) -- clear highlights

  local value = vim.api.nvim_buf_get_lines(self.buf, 0, 1, false)[1] or ""
  local used = string.len(value)
  vim.api.nvim_buf_set_extmark(self.buf, self.ns, 0, 0, {
    virt_text = {
      {string.format("%d/%d", used, self.keymap_length), "Comment"}
    },
    virt_text_pos = "right_align",
  })

  local virtual_lines = {} ---@type string[][][]

  local next_key_index = used + 1
  for _, file in ipairs(self.filtered_files) do
    local path = keymaps.truncate_path(file.path, self.win_width - 2)
    local keymap_indexes = keymaps.keymap_location_in_path(path, file.keymap, {missing_behavior = "nearby"})
    local path_line = keymaps.highlight_path_virtual_text(path, file.keymap, keymap_indexes, {next_key_index = next_key_index})
    table.insert(virtual_lines, path_line)
  end

  vim.api.nvim_buf_set_extmark(self.buf, self.ns, 0, 0, {
    virt_lines = virtual_lines,
    virt_lines_above = false,
    virt_lines_leftcol = false,
  })
end

function Jumper:draw_footer()
  vim.api.nvim_buf_clear_namespace(self.footer_buf, self.footer_ns, 0, -1)
  local help_line = {{" "}} ---@type string[][]
  local curr_mode = vim.api.nvim_get_mode().mode
  if curr_mode == "n" then
    table.insert(help_line, {"k", "Function"})
    table.insert(help_line, {" Keymap"})
    table.insert(help_line, {"  "})
    table.insert(help_line, {"p", "Function"})
    table.insert(help_line, {" Project"})
  else
    table.insert(help_line, {"k Keymap", "Comment"})
    table.insert(help_line, {"  "})
    table.insert(help_line, {"p Project", "Comment"})
  end
  vim.api.nvim_buf_set_extmark(self.footer_buf, self.footer_ns, 0, 0, {
    virt_text = help_line,
    virt_text_pos = "overlay",
  })

  local project_line = {{" " .. self.project.name .. " ", "hopper.hl.ProjectTag"}, {" "}}
  vim.api.nvim_buf_set_extmark(self.footer_buf, self.footer_ns, 0, 0, {
    virt_text = project_line,
    virt_text_pos = "right_align",
  })
end

function Jumper:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  if vim.api.nvim_win_is_valid(self.footer_win) then
    vim.api.nvim_win_close(self.footer_win, true)
  end
  Jumper._reset(self)
end

---@class hopper.NewReopenJumperOptions
---@field project_source "self" | "current"

---@param opts? hopper.NewReopenJumperOptions
---@return fun(el?: hopper.Keymapper | hopper.NewProjectForm)
function Jumper:_new_reopen_callback(opts)
  opts = opts or {}
  local prior_buf = self.prior_buf
  local project = self.project
  return function(el)
    if el ~= nil then
      el:close()
    end
    if opts.project_source == "current" then
      project = projects.current_project()
    end
    self:open({prior_buf = prior_buf, project = project})
  end
end

---@param files hopper.FileMapping[]
-- Set the list of files, including building out a tree of keymaps to file paths. This tree is
-- important when determining whether a file keymapping has been activated during the text change
-- handler.
function Jumper:_set_files(files)
  local tree = {} ---@type hopper.KeymapFileTree
  for _, file in ipairs(files) do
    local node = tree ---@type hopper.KeymapFileNode | hopper.KeymapFileTree
    for i = 1, string.len(file.keymap) do
      local key = string.sub(file.keymap, i, i)
      if node[key] == nil then
        node[key] = {} ---@type hopper.KeymapFileTree
      end
      if i == string.len(file.keymap) then
        ---@type any Can't handle recursive types like this.
        node[key] = file
      end
      node = node[key]
    end
  end
  self.files = files
  self.filtered_files = files
  self.keymap_file_tree = tree
end

function Jumper:_attach_event_handlers()
  local buf = self.buf

  vim.api.nvim_create_autocmd({"TextChangedI", "TextChanged", "TextChangedP"}, {
    buffer = buf,
    callback = function()
      local value = utils.clamp_buffer_value_chars(buf, self.keymap_length)
      -- Clear the `modified` flag for prompt so we can close without saving.
      vim.bo[buf].modified = false
      if string.len(value) < 1 then
        -- All input text has been deleted. Reset the filtered files list back to its default value
        -- and bail.
        self.filtered_files = self.files
        self:draw()
        return
      end
      -- The `keymap_file_tree` is a nested table. Leaf nodes are file mappings, and interim nodes
      -- are single characters in a keymap. For example, it might look something like
      --
      -- {
      --   i = {
      --     l = {
      --       path = "~/init.lua",
      --     },
      --     v = {
      --       path = "~/init.vim",
      --     },
      --   },
      -- }
      --
      -- In this case, we'd expect the selected value for input "i" to be the table containing keys
      -- "l" and "v". The selected value for input "iv" would be the "init.vim" file mapping object.
      local selected = vim.tbl_get(self.keymap_file_tree, unpack(vim.split(value, ""))) ---@type hopper.FileMapping | hopper.KeymapFileTree | nil
      if selected == nil then
        -- No selection found. Empty out the list and bail.
        self.filtered_files = {}
        self:draw()
        return
      end
      if selected.path ~= nil then
        -- The selected object is a valid file. Open it.
        vim.print(selected)
        local path = selected.path ---@type string
        local open_cmd = self.open_cmd
        self:close()
        -- Need to defer the new file load so that this float can properly finish closing before
        -- attempting to render the file. Failing to do so results in the new buffer only being
        -- partially initialized.
        vim.schedule(function()
          utils.open_or_focus_file(path, {open_cmd = open_cmd})
        end)
      else
        -- The selected object is another set of poossible next characters in the keymap.
        -- Filter the visible list down to only files that are possible to select from this keymap
        -- so far.
        local filtered_files = {} ---@type hopper.FileMapping[]
        local stack = vim.tbl_values(selected) ---@type (hopper.FileMapping | hopper.KeymapFileNode)[]
        while #stack > 0 do
          local item = table.remove(stack, 1) ---@type hopper.FileMapping | hopper.KeymapFileNode
          if item.path then
            table.insert(filtered_files, item)
          else
            for _, child in pairs(item) do
              table.insert(stack, child)
            end
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

  -- Open new keymap view on "k" keypress.
  vim.keymap.set(
    "n",
    "k",
    function()
      local path = projects.path_from_project_root(self.project.path, vim.api.nvim_buf_get_name(self.prior_buf))
      local reopen_jumper = self:_new_reopen_callback()
      require("hopper.view.keymapper").form():open(
        path,
        {
          project = self.project,
          on_back = reopen_jumper,
          on_keymap_set = reopen_jumper,
        }
      )
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  -- Open project menu on "p" keypress.
  vim.keymap.set(
    "n",
    "p",
    function()
      local reopen_jumper = self:_new_reopen_callback({project_source = "current"})
      require("hopper.view.project_ui").open_project_menu({
        on_new_project_created = reopen_jumper,
        on_current_project_changed = reopen_jumper,
        on_project_deleted = reopen_jumper,
      })
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )

  utils.attach_close_events({
    buffer = buf,
    on_close = function()
      self:close()
    end,
    keypress_events = {"<esc>"},
    vim_change_events = {"WinLeave", "BufWipeout"},
  })
end

local _float = nil ---@type hopper.Jumper | nil

---@return hopper.Jumper
function M.float()
  if _float == nil then
    _float = Jumper._new()
  end
  return _float
end

return M
