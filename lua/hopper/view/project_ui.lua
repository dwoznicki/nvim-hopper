local projects = require("hopper.projects")
local utils = require("hopper.utils")

local loop = vim.uv or vim.loop

---@class hopper.NewProjectFormValidationError
---@field code "empty_field" | "no_such_directory" | "project_exists"
---@field message string

local M = {}

---@class hopper.NewProjectForm
---@field name string
---@field path string
---@field step integer
---@field buf integer
---@field win integer
---@field validation hopper.NewProjectFormValidationError | nil
local NewProjectForm = {}
NewProjectForm.__index = NewProjectForm
M.NewProjectForm = NewProjectForm

NewProjectForm.default_win_height = 3
NewProjectForm.ns = vim.api.nvim_create_namespace("hopper.NewProjectForm")

---@return hopper.NewProjectForm
function NewProjectForm._new()
  local form = {}
  setmetatable(form, NewProjectForm)
  NewProjectForm._reset(form)
  return form
end

---@param form hopper.NewProjectForm
function NewProjectForm._reset(form)
  form.name = ""
  form.path = ""
  form.step = -1
  form.buf = -1
  form.win = -1
  form.validation = nil
end

function NewProjectForm:open()
  self.step = 1

  local ui = vim.api.nvim_list_uis()[1]
  local win_width, _ = utils.get_win_dimensions()
  self.win_width = win_width

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "prompt", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("buflisted", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "HopperFloat", {buf = buf})
  ---@type vim.api.keyset.win_config
  local win_config = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = self.default_win_height,
    row = 3,
    col = math.floor((ui.width - win_width) * 0.5),
    focusable = true,
    title = " New project ",
    title_pos = "center",
    border = "rounded",
  }
  -- Don't show the prompt text.
  vim.fn.prompt_setprompt(buf, "")
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

function NewProjectForm:draw()
  vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1)

  local label = ""
  if self.step == 1 then
    -- vim.fn.prompt_setprompt(self.buf, "Name ")
    label = "Project name"
  elseif self.step == 2 then
    -- vim.fn.prompt_setprompt(self.buf, "Path ")
    label = "Project path"
  end

  vim.api.nvim_buf_set_extmark(self.buf, self.ns, 0, 0, {
    virt_text = {{label, "Comment"}, {" "}},
    virt_text_pos = "right_align",
  })

  local lines = {} ---@type string[][][]

  local state_line = {} ---@type string[][]
  table.insert(state_line, {
    string.len(self.name) > 0 and self.name or "Project name",
    self.step == 1 and "hopper.hl.SelectedText" or "hopper.hl.SecondaryText",
  })
  table.insert(state_line, {" - ", "hopper.hl.SecondaryText"})
  table.insert(state_line, {
    string.len(self.path) > 0 and self.path or "Project path",
    self.step == 2 and "hopper.hl.SelectedText" or "hopper.hl.SecondaryText",
  })
  table.insert(lines, state_line)

  local error_line = nil ---@type string[][] | nil
  local next_win_height ---@type integer
  if self.validation ~= nil then
    next_win_height = self.default_win_height + 1
    error_line = {
      {self.validation.message, "Error"},
    }
  else
    next_win_height = self.default_win_height
  end
  if vim.api.nvim_win_get_height(self.win) ~= next_win_height then
    vim.api.nvim_win_set_height(self.win, next_win_height)
  end
  if error_line ~= nil then
    table.insert(lines, error_line)
  end

  local help_line = {{"  "}} ---@type string[][]
  local has_values = string.len(self.name) > 0 and string.len(self.path) > 0
  if has_values then
    table.insert(help_line, {"󰌑 ", "Function"})
    table.insert(help_line, {" Confirm"})
  else
    table.insert(help_line, {"󰌑  Confirm", "Comment"})
  end
  table.insert(help_line, {"  "})
  local curr_mode = vim.api.nvim_get_mode().mode
  if curr_mode == "n" then
    table.insert(help_line, {"󰌒 ", "String"})
    table.insert(help_line, {" Next field"})
  else
    table.insert(help_line, {"󰌒  Next field", "Comment"})
  end
  table.insert(lines, help_line)

  vim.api.nvim_buf_set_extmark(self.buf, self.ns, 0, 0, {
    virt_lines = lines,
    virt_lines_above = false,
    virt_lines_leftcol = false,
  })
end

function NewProjectForm:confirm()
  self:validate()
  if self.validation ~= nil then
    self:draw()
    return
  end
  local datastore = require("hopper.db").datastore()
  datastore:set_project(self.name, self.path)
  self:close()
end

function NewProjectForm:validate()
  if string.len(self.name) < 1 or string.len(self.path) < 1 then
    self.validation = {
      code = "empty_field",
      message = "Project name and path cannot be empty.",
    }
    return
  end
  local path_stat = loop.fs_stat(self.path)
  if not path_stat or path_stat.type ~= "directory" then
    self.validation = {
      code = "no_such_directory",
      message = string.format("Could not resolve directory \"%s\".", self.path),
    }
    return
  end
  local datastore = require("hopper.db").datastore()
  local project_by_name = datastore:get_project_by_name(self.name)
  if project_by_name ~= nil then
    self.validation = {
      code = "project_exists",
      message = string.format("Project with name \"%s\" already exists.", self.name),
    }
    return
  end
  local project_by_path = datastore:get_project_by_path(self.path)
  if project_by_path ~= nil then
    self.validation = {
      code = "project_exists",
      message = string.format("Project with path \"%s\" already exists.", self.path),
    }
    return
  end
  self.validation = nil
end

function NewProjectForm:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  NewProjectForm._reset(self)
end

function NewProjectForm:_attach_event_handlers()
  local buf = self.buf
  vim.api.nvim_create_autocmd({"TextChangedI", "TextChanged", "TextChangedP"}, {
    buffer = buf,
    callback = function()
      local value = utils.clamp_buffer_value(buf)
      -- Clear the `modified` flag for prompt so we can close without saving.
      vim.bo[buf].modified = false
      if self.step == 1 then
        self.name = value
      elseif self.step == 2 then
        self.path = value
      end
      local form = self
      vim.schedule(function()
        form:draw()
      end)
    end,
  })

  vim.api.nvim_create_autocmd("ModeChanged", {
    buffer = buf,
    callback = function()
      self:draw()
    end,
  })

  vim.keymap.set(
    {"i", "n"},
    "<cr>",
    function()
      self:confirm()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  -- Next field on tab keypress.
  vim.keymap.set(
    "n",
    "<tab>",
    function()
      if self.step == 1 then
        self.step = 2
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {self.path})
      else
        self.step = 1
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {self.name})
      end
      self:draw()
    end,
    {noremap = true, silent = true, nowait = true, buffer = buf}
  )
  -- Close on q keypress.
  vim.keymap.set(
    "n",
    "q",
    function()
      self:close()
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

---@return boolean
function NewProjectForm:_form_ok()
  return string.len(self.name) > 0 and string.len(self.path) > 0
end

local _form = nil ---@type hopper.NewProjectForm | nil

---@return hopper.NewProjectForm
function M.form()
  if _form == nil then
    _form = NewProjectForm._new()
  end
  return _form
end

function M.open_project_menu()
  vim.ui.select(
    {
      "Create new project",
      "Change current project",
    },
    {
      prompt = "Select an option",
    },
    function(_, idx)
      if idx == 1 then
        M.form():open()
      elseif idx == 2 then
        M.change_current_project()
      end
    end
  )
end

function M.change_current_project()
  local added_names = {} ---@type table<string, true>
  local project_items = {} ---@type hopper.Project[]

  local projects_from_path = projects.list_projects_from_path(vim.api.nvim_buf_get_name(0))
  for _, project in ipairs(projects_from_path) do
    if added_names[project.name] == nil then
      table.insert(project_items, project)
      added_names[project.name] = true
    end
  end

  local datastore = require("hopper.db").datastore()
  local saved_projects = datastore:list_projects()
  for _, project in ipairs(saved_projects) do
    if added_names[project.name] == nil then
      table.insert(project_items, project)
      added_names[project.name] = true
    end
  end

  vim.ui.select(
    project_items,
    {
      prompt = "Choose a project",
      format_item = function(item)
        return string.format("%s - %s", item.name, item.path)
      end,
    },
    function(choice)
      if choice ~= nil then
        projects.set_current_project(choice)
      end
    end
  )
end

return M
