local utils = require("hopper.utils")
local keymaps = require("hopper.keymaps")
local projects = require("hopper.projects")
local options = require("hopper.options")
local keymapper_view = require("hopper.view.keymapper")
local project_menu_view = require("hopper.view.project_menu")
local footer_view = require("hopper.view.footer")

local M = {}

---@alias hopper.KeymapFileTree table<string, hopper.KeymapFileNode>
---@alias hopper.KeymapFileNode hopper.KeymapFileTree | hopper.FileKeymap

---@class hopper.Hopper
---@field project hopper.Project | nil
---@field files hopper.FileKeymap[]
---@field is_open boolean
---@field keymap_file_tree hopper.KeymapFileTree
---@field filtered_files hopper.FileKeymap[]
---@field buf integer
---@field win integer
---@field win_width integer
---@field footer_buf integer
---@field footer_win integer
---@field prior_buf integer
---@field keymap_length integer
---@field open_cmd string | nil
---@field actions table<hopper.HopperViewAction, string[]>
local Hopper = {}
Hopper.__index = Hopper
M.Hopper = Hopper

Hopper.ns = vim.api.nvim_create_namespace("hopper.Hopper")
Hopper.footer_ns = vim.api.nvim_create_namespace("hopper.HopperFooter")

---@return hopper.Hopper
function Hopper._new()
  local instance = {}
  setmetatable(instance, Hopper)
  Hopper._reset(instance)
  return instance
end

---@param instance hopper.Hopper
function Hopper._reset(instance)
  instance.project = nil
  instance.files = {}
  instance.is_open = false
  instance.keymap_file_tree = {}
  instance.filtered_files = {}
  instance.buf = -1
  instance.win = -1
  instance.win_width = -1
  instance.footer_buf = -1
  instance.footer_win = -1
  instance.prior_buf = -1
  instance.keymap_length = -1
  instance.open_cmd = nil
  instance.actions = {}
end

---@class hopper.OpenHopperOptions
---@field project hopper.Project | string | nil
---@field prior_buf integer | nil
---@field keymap_length integer | nil
---@field open_cmd string | nil
---@field width integer | decimal | nil
---@field height integer | decimal | nil

---@param opts? hopper.OpenHopperOptions
function Hopper:open(opts)
  opts = opts or {}
  local full_options = options.options()
  -- Initial setup
  self.project = projects.ensure_project(opts.project)
  self.prior_buf = opts.prior_buf or vim.api.nvim_get_current_buf()
  self.keymap_length = opts.keymap_length or full_options.keymapping.length
  self.open_cmd = opts.open_cmd or full_options.keymapping.default_open_cmd
  if self.open_cmd ~= nil and string.len(self.open_cmd) < 1 then
    vim.notify_once(string.format('Open command "%s" is invalid.', self.open_cmd), vim.log.levels.WARN)
  end
  self.actions = full_options.actions.hopper

  local ui = vim.api.nvim_list_uis()[1]
  local opts_width = opts.width or full_options.float.width
  local opts_height = opts.height or full_options.float.height
  local win_width, win_height = utils.get_win_dimensions(opts_width, opts_height)
  self.win_width = win_width

  local datastore = require("hopper.db").datastore()
  local files = datastore:list_file_keymaps(self.project.name, self.keymap_length)
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
    zindex = 51, -- Just enough to site on top of the hopper window.
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

function Hopper:draw()
  vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1) -- clear highlights

  local value = vim.api.nvim_buf_get_lines(self.buf, 0, 1, false)[1] or ""
  local used = string.len(value)
  vim.api.nvim_buf_set_extmark(self.buf, self.ns, 0, 0, {
    virt_text = {
      {string.format("%d/%d", used, self.keymap_length), "hopper.DisabledText"}
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

function Hopper:draw_footer()
  vim.api.nvim_buf_clear_namespace(self.footer_buf, self.footer_ns, 0, -1)

  local curr_mode = vim.api.nvim_get_mode().mode
  local help_line = footer_view.build_help_line({
    {
      keymaps = self.actions.open_keymapper,
      label = "Keymap",
      enabled = curr_mode == "n",
    },
    {
      keymaps = self.actions.open_picker,
      label = "Picker",
      enabled = curr_mode == "n",
    },
    {
      keymaps = self.actions.open_project_menu,
      label = "Project",
      enabled = curr_mode == "n",
    },
  })
  vim.api.nvim_buf_set_extmark(self.footer_buf, self.footer_ns, 0, 0, {
    virt_text = help_line,
    virt_text_pos = "overlay",
  })

  local project_line = {{" " .. self.project.name .. " ", "hopper.ProjectTag"}, {" "}}
  vim.api.nvim_buf_set_extmark(self.footer_buf, self.footer_ns, 0, 0, {
    virt_text = project_line,
    virt_text_pos = "right_align",
  })
end

function Hopper:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  if vim.api.nvim_win_is_valid(self.footer_win) then
    vim.api.nvim_win_close(self.footer_win, true)
  end
  Hopper._reset(self)
end

---@class hopper.NewReopenHopperOptions
---@field project_source "self" | "current"

---@param opts? hopper.NewReopenHopperOptions
---@return fun(el?: hopper.Keymapper | hopper.NewProjectForm)
function Hopper:_new_reopen_callback(opts)
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

---@param files hopper.FileKeymap[]
-- Set the list of files, including building out a tree of keymaps to file paths. This tree is
-- important when determining whether a file keymapping has been activated during the text change
-- handler.
function Hopper:_set_files(files)
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
      -- lua_ls doesn't do well with recursive types.
      ---@diagnostic disable-next-line cast-local-type
      node = node[key]
    end
  end
  utils.sort_file_keymaps(files)
  self.files = files
  self.filtered_files = files
  self.keymap_file_tree = tree
end

function Hopper:_attach_event_handlers()
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
      local selected = vim.tbl_get(self.keymap_file_tree, unpack(vim.split(value, ""))) ---@type hopper.FileKeymap | hopper.KeymapFileTree | nil
      if selected == nil then
        -- No selection found. Empty out the list and bail.
        self.filtered_files = {}
        self:draw()
        return
      end
      if selected.path ~= nil then
        -- The selected object is a valid file. Open it.
        local path = projects.path_from_cwd(self.project.path, selected.path)
        local open_cmd = self.open_cmd
        self:close()
        -- Need to defer the new file load so that this float can properly finish closing before
        -- attempting to render the file. Failing to do so results in the new buffer only being
        -- partially initialized.
        vim.schedule(function()
          utils.open_or_focus_file(path, {open_cmd = open_cmd})
        end)
      else
        -- The selected object is another set of possible next characters in the keymap.
        -- Filter the visible list down to only files that are possible to select from this keymap
        -- so far.
        local filtered_files = {} ---@type hopper.FileKeymap[]
        local stack = vim.tbl_values(selected) ---@type (hopper.FileKeymap | hopper.KeymapFileNode)[]
        while #stack > 0 do
          local item = table.remove(stack, 1) ---@type hopper.FileKeymap | hopper.KeymapFileNode
          if item.path then
            table.insert(filtered_files, item)
          else
            for _, child in pairs(item) do
              table.insert(stack, child)
            end
          end
        end
        utils.sort_file_keymaps(filtered_files)
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

  -- Open new keymapper view.
  local function open_keymapper()
    local path = projects.path_from_project_root(self.project.path, vim.api.nvim_buf_get_name(self.prior_buf))
    if path == "." then
      -- The project root is currently open. Making a mapping for it is probably a mistake.
      vim.notify("Cannot assign a keymap to project root directory.", vim.log.levels.WARN)
      return
    end
    local reopen_hopper = self:_new_reopen_callback()
    keymapper_view.Keymapper.instance():open(
      path,
      {
        project = self.project,
        on_back = reopen_hopper,
        on_keymap_set = reopen_hopper,
      }
    )
  end
  local open_keymapper_keymaps = self.actions.open_keymapper
  for _, keymap in ipairs(open_keymapper_keymaps) do
    vim.keymap.set(
      "n",
      keymap,
      open_keymapper,
      {noremap = true, silent = true, nowait = true, buffer = buf}
    )
  end

  -- Open picker view.
  local function open_file_keymaps_picker()
    require("hopper.view.picker").open_file_keymaps_picker({
      project_filter = self.project.name,
    })
  end
  local open_picker_keymaps = self.actions.open_picker
  for _, keymap in ipairs(open_picker_keymaps) do
    vim.keymap.set(
      "n",
      keymap,
      open_file_keymaps_picker,
      {noremap = true, silent = true, nowait = true, buffer = buf}
    )
  end

  -- Open project menu view.
  local function open_project_menu()
    local reopen_hopper = self:_new_reopen_callback({project_source = "current"})
    project_menu_view.open_project_menu({
      on_new_project_created = reopen_hopper,
      on_current_project_changed = reopen_hopper,
      on_project_deleted = reopen_hopper,
    })
  end
  local open_project_menu_keymaps = self.actions.open_project_menu
  for _, keymap in ipairs(open_project_menu_keymaps) do
    vim.keymap.set(
      "n",
      keymap,
      open_project_menu,
      {noremap = true, silent = true, nowait = true, buffer = buf}
    )
  end

  utils.attach_close_events({
    buffer = buf,
    on_close = function()
      self:close()
    end,
    keypress_events = self.actions.close,
    vim_change_events = {"WinLeave", "BufWipeout"},
  })
end

Hopper._instance = nil ---@type hopper.Hopper | nil

---@return hopper.Hopper
function Hopper.instance()
  if Hopper._instance == nil then
    Hopper._instance = Hopper._new()
  end
  return Hopper._instance
end

return M
