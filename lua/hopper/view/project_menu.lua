local projects = require("hopper.projects")
local utils = require("hopper.utils")
local options = require("hopper.options")
local footer_view = require("hopper.view.footer")

local loop = vim.uv or vim.loop

---@alias hopper.NewProjectFormValidationCode "name_field_empty" | "project_field_empty" | "no_such_directory" | "project_name_exists" | "project_path_exists"

---@class hopper.NewProjectFormValidation
---@field code hopper.NewProjectFormValidationCode
---@field message string

local M = {}

---@class hopper.NewProjectForm
---@field name string
---@field path string
---@field buf integer
---@field win integer
---@field footer_buf integer
---@field footer_win integer
---@field validation hopper.NewProjectFormValidation | nil
---@field suggested_project hopper.Project | nil
---@field is_open boolean
---@field actions table<hopper.NewProjectViewAction, string[]>
---@field on_created fun(form: hopper.NewProjectForm) | nil
---@field on_cancel fun(form: hopper.NewProjectForm) | nil
local NewProjectForm = {}
NewProjectForm.__index = NewProjectForm
M.NewProjectForm = NewProjectForm

NewProjectForm.default_win_height = 4
NewProjectForm.default_footer_win_height = 2
NewProjectForm.ns = vim.api.nvim_create_namespace("hopper.NewProjectForm")
NewProjectForm.footer_ns = vim.api.nvim_create_namespace("hopper.NewProjectFormFooter")

---@return hopper.NewProjectForm
function NewProjectForm._new()
  local form = {}
  setmetatable(form, NewProjectForm)
  NewProjectForm._reset(form)
  return form
end

---@param instance hopper.NewProjectForm
function NewProjectForm._reset(instance)
  instance.name = ""
  instance.path = ""
  instance.buf = -1
  instance.win = -1
  instance.footer_buf = -1
  instance.footer_win = -1
  instance.validation = nil
  instance.suggested_project = nil
  instance.is_open = false
  instance.actions = {}
  instance.on_created = nil
  instance.on_cancel = nil
end

---@class hopper.NewProjectFormOpenOptions
---@field on_created fun(form: hopper.NewProjectForm) | nil
---@field on_cancel fun(form: hopper.NewProjectForm) | nil
---@field width integer | decimal | nil

---@param opts? hopper.NewProjectFormOpenOptions
function NewProjectForm:open(opts)
  opts = opts or {}
  local full_options = options.options()
  self.actions = full_options.actions.new_project
  self.on_created = opts.on_created
  self.on_cancel = opts.on_cancel

  local ui = vim.api.nvim_list_uis()[1]
  local opts_width = opts.width or full_options.float.width
  local win_width, _ = utils.get_win_dimensions(opts_width, 0)
  self.win_width = win_width

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
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
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = buf,
    callback = function()
      vim.cmd("startinsert")
    end,
  })
  local win = vim.api.nvim_open_win(buf, true, win_config)
  -- Create two empty lines in buffer.
  utils.clamp_buffer_value_lines(buf, 2, {exact = true})
  local statuscolumn_vimscript = "%#hopper.ProjectText#%{v:lnum==1?'Name ':v:lnum==2?'Path ':'     '}%*"
  vim.api.nvim_set_option_value("statuscolumn", statuscolumn_vimscript, {win = win})

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
    height = self.default_footer_win_height,
    row = win_config.row + win_config.height - 1,
    col = win_config.col + 1,
    focusable = false,
    border = "none",
    zindex = 51, -- Just enough to site on top of the main window.
  }
  local footer_win = vim.api.nvim_open_win(footer_buf, false, footer_win_config)

  self.buf = buf
  self.win = win
  self.footer_buf = footer_buf
  self.footer_win = footer_win
  self.is_open = true

  self:_attach_event_handlers()

  self:draw_footer()

  vim.schedule(function()
    self:_suggest_project()
  end)
end

function NewProjectForm:draw_footer()
  vim.api.nvim_buf_clear_namespace(self.footer_buf, self.footer_ns, 0, -1)

  local lines = {} ---@type string[][][]

  local error_line = nil ---@type string[][] | nil
  local next_win_height ---@type integer
  local next_footer_win_height ---@type integer
  if self.validation ~= nil then
    local hl ---@type string
    if self.validation.code == "no_such_directory" or self.validation.code == "project_name_exists" then
      hl = "WarningMsg"
    else
      hl = "ErrorMsg"
    end
    error_line = {
      {self.validation.message, hl},
    }
    next_win_height = self.default_win_height + 1
    next_footer_win_height = self.default_footer_win_height + 1
  else
    next_win_height = self.default_win_height
    next_footer_win_height = self.default_footer_win_height
  end
  if vim.api.nvim_win_get_height(self.win) ~= next_win_height then
    vim.api.nvim_win_set_height(self.win, next_win_height)
    vim.api.nvim_win_set_height(self.footer_win, next_footer_win_height)
  end
  if error_line ~= nil then
    table.insert(lines, error_line)
  end

  local has_values = string.len(self.name) > 0 and string.len(self.path) > 0
  local help_line = footer_view.build_help_line({
    {
      keymaps = self.actions.confirm,
      label = "Confirm",
      enabled = has_values,
    },
    {
      keymaps = self.actions.accept_suggestion,
      label = "Accept suggestion",
      enabled = self.suggested_project ~= nil,
    },
  })
  table.insert(lines, help_line)

  vim.api.nvim_buf_set_extmark(self.footer_buf, self.footer_ns, 0, 0, {
    virt_lines = lines,
    virt_lines_above = false,
    virt_lines_leftcol = false,
  })
end

function NewProjectForm:confirm()
  local prev_code = self.validation and self.validation.code or nil
  self:validate()
  if self.validation ~= nil and not self.can_validation_be_forced(self.validation.code, prev_code) then
    self:draw_footer()
    return
  end
  local datastore = require("hopper.db").datastore()
  datastore:set_project(self.name, self.path)
  vim.schedule(function()
    if self.on_created ~= nil then
      self.on_created(self)
    else
      self:close()
    end
  end)
end

function NewProjectForm:validate()
  if string.len(self.name) < 1 then
    self.validation = {
      code = "name_field_empty",
      message = "Project name cannot be empty.",
    }
    return
  end
  if string.len(self.path) < 1 then
    self.validation = {
      code = "project_field_empty",
      message = "Project path cannot be empty.",
    }
    return
  end
  local path_stat = loop.fs_stat(self.path)
  if not path_stat or path_stat.type ~= "directory" then
    self.validation = {
      code = "no_such_directory",
      message = string.format("Could not resolve directory \"%s\". Use it anyway?", self.path),
    }
    return
  end
  local datastore = require("hopper.db").datastore()
  local project_by_name = datastore:get_project_by_name(self.name)
  if project_by_name ~= nil then
    self.validation = {
      code = "project_name_exists",
      message = string.format("Project with name \"%s\" already exists. Update the project path?", self.name),
    }
    return
  end
  local project_by_path = datastore:get_project_by_path(self.path)
  if project_by_path ~= nil then
    self.validation = {
      code = "project_path_exists",
      message = string.format("Project with path \"%s\" already exists.", self.path),
    }
    return
  end
  self.validation = nil
end

---@param code hopper.NewProjectFormValidationCode
---@param prev_code hopper.NewProjectFormValidationCode | nil
---@return boolean
function NewProjectForm.can_validation_be_forced(code, prev_code)
  -- Don't allow forcing new validation errors. We can only force when the new validation is the
  -- same as the previous validation type.
  if code ~= prev_code then
    return false
  end
  return code == "project_name_exists" or code == "no_such_directory"
end

function NewProjectForm:accept_suggestion()
  if self.suggested_project == nil then
    return
  end
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, {
    self.suggested_project.name,
    self.suggested_project.path,
  })
  self:clear_suggestion()
end

function NewProjectForm:clear_suggestion()
  vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1)
  self.suggested_project = nil
  self:draw_footer()
end

function NewProjectForm:close()
  if vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  if vim.api.nvim_win_is_valid(self.footer_win) then
    vim.api.nvim_win_close(self.footer_win, true)
  end
  NewProjectForm._reset(self)
end

function NewProjectForm:_attach_event_handlers()
  local buf = self.buf
  vim.api.nvim_create_autocmd({"TextChangedI", "TextChanged", "TextChangedP"}, {
    buffer = buf,
    callback = function()
      local lines = utils.clamp_buffer_value_lines(buf, 2, {exact = true})
      self.name = lines[1]
      self.path = lines[2]
      if string.len(self.name) > 0 or string.len(self.path) > 0 then
        self:clear_suggestion()
      end
      vim.schedule(function()
        self.validation = nil
        self:draw_footer()
      end)
    end,
  })

  vim.api.nvim_create_autocmd("ModeChanged", {
    buffer = buf,
    callback = function()
      self:draw_footer()
    end,
  })

  -- Confirm new project.
  local confirm_keymaps = self.actions.confirm
  for _, keymap in ipairs(confirm_keymaps) do
    vim.keymap.set(
      {"i", "n"},
      keymap,
      function()
        local has_values = string.len(self.name) > 0 and string.len(self.path) > 0
        if has_values then
          self:confirm()
          return ""
        end
        -- Fallback to default return behavior.
        return vim.api.nvim_replace_termcodes("<cr>", true, false, true)
      end,
      {noremap = true, silent = true, nowait = true, expr = true, buffer = buf}
    )
  end

  -- Accept suggestion.
  local accept_suggestion_keymaps = self.actions.accept_suggestion
  for _, keymap in ipairs(accept_suggestion_keymaps) do
    vim.keymap.set(
      {"i", "n"},
      keymap,
      function()
        if self.suggested_project ~= nil then
          vim.schedule(function()
            self:accept_suggestion()
          end)
          return ""
        end
        -- Fallback to default tab behavior.
        return vim.api.nvim_replace_termcodes("<tab>", true, false, true)
      end,
      {noremap = true, silent = true, nowait = true, expr = true, buffer = buf}
    )
  end

  utils.attach_close_events({
    buffer = buf,
    on_close = function()
      if self.on_cancel ~= nil then
        self.on_cancel(self)
      else
        self:close()
      end
    end,
    keypress_events = self.actions.close,
    vim_change_events = {"WinLeave", "BufWipeout"},
  })
end

function NewProjectForm:_suggest_project()
  local datastore = require("hopper.db").datastore()
  local existing_projects = datastore:list_projects()
  local existing_projects_by_path = {} ---@type table<string, hopper.Project>
  for _, project in ipairs(existing_projects) do
    existing_projects_by_path[project.path] = project
  end

  local base_path = loop.cwd()
  local possible_projects = projects.list_projects_from_path(base_path)
  local suggested_project = nil ---@type hopper.Project | nil
  for _, possible_project in ipairs(possible_projects) do
    if existing_projects_by_path[possible_project.path] == nil then
      -- We don't hae a project at this path yet. We'll go ahead and use this one as the
      -- suggestion.
      suggested_project = possible_project
      break
    end
  end
  if suggested_project ~= nil then
    vim.schedule(function()
      if string.len(self.name) < 1 and string.len(self.path) < 1 then
        self.suggested_project = suggested_project
        vim.api.nvim_buf_set_extmark(self.buf, self.ns, 0, 0, {
          virt_text = {{suggested_project.name, "hopper.DisabledText"}},
          virt_text_pos = "overlay",
        })
        vim.api.nvim_buf_set_extmark(self.buf, self.ns, 1, 0, {
          virt_text = {{suggested_project.path, "hopper.DisabledText"}},
          virt_text_pos = "overlay",
        })
        self:draw_footer()
      end
    end)
  end
end

---@return boolean
function NewProjectForm:_form_ok()
  return string.len(self.name) > 0 and string.len(self.path) > 0
end

NewProjectForm._instance = nil ---@type hopper.NewProjectForm | nil

---@return hopper.NewProjectForm
function NewProjectForm.instance()
  if NewProjectForm._instance == nil then
    NewProjectForm._instance = NewProjectForm._new()
  end
  return NewProjectForm._instance
end

---@class hopper.ListAvailableProjectItemsOptions
---@field mode "saved_only" | nil

---@param opts? hopper.ListAvailableProjectItemsOptions
---@return hopper.Project[]
local function list_available_project_items(opts)
  opts = opts or {}
  local mode = opts.mode

  local added_names = {} ---@type table<string, true>
  local project_items = {} ---@type hopper.Project[]

  if mode ~= "saved_only" then
    local projects_from_path = projects.list_projects_from_path(vim.api.nvim_buf_get_name(0))
    for _, project in ipairs(projects_from_path) do
      if added_names[project.name] == nil then
        table.insert(project_items, project)
        added_names[project.name] = true
      end
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
  return project_items
end

---@class hopper.ChangeCurrentProjectOptions
---@field on_changed? fun()

---@param opts? hopper.ChangeCurrentProjectOptions
function M.change_current_project(opts)
  opts = opts or {}
  local project_items = list_available_project_items()

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
        if opts.on_changed ~= nil then
          opts.on_changed()
        end
      end
    end
  )
end

---@class hopper.DeleteProjectOptions
---@field on_deleted? fun()

---@param opts? hopper.DeleteProjectOptions
function M.delete_project(opts)
  opts = opts or {}
  local project_items = list_available_project_items({mode = "saved_only"})

  vim.ui.select(
    project_items,
    {
      prompt = "Choose a project to delete",
      format_item = function(item)
        return string.format("%s - %s", item.name, item.path)
      end,
    },
    function(choice)
      if choice ~= nil then
        local curr_project = projects.current_project()
        local datastore = require("hopper.db").datastore()
        datastore:remove_project(choice.name)
        vim.notify(string.format("Project %s deleted.", choice.name))
        if choice.name == curr_project.name then
          -- Just deleted our current project. Find a new project to serve as the current.
          local next_projects = projects.list_projects_from_path(loop.cwd())
          if #next_projects > 0 then
            projects.set_current_project(next_projects[1])
          else
            for _, project in ipairs(project_items) do
              if project.name ~= choice.name then
                projects.set_current_project(project)
                break
              end
            end
          end
        end
        if opts.on_deleted ~= nil then
          opts.on_deleted()
        end
      end
    end
  )
end

---@class hopper.OpenProjectMenuOptions
---@field on_new_project_created fun(form: hopper.NewProjectForm) | nil
---@field on_current_project_changed fun() | nil
---@field on_project_deleted fun() | nil

---@param opts? hopper.OpenProjectMenuOptions
function M.open_project_menu(opts)
  opts = opts or {}
  vim.ui.select(
    {
      "Create new project",
      "Change current project",
      "Delete project",
    },
    {
      prompt = "Select an option",
    },
    function(_, idx)
      if idx == 1 then
        NewProjectForm.instance():open({
          on_created = opts.on_new_project_created,
        })
      elseif idx == 2 then
        M.change_current_project({
          on_changed = opts.on_current_project_changed,
        })
      elseif idx == 3 then
        M.delete_project({
          on_deleted = opts.on_project_deleted,
        })
      end
    end
  )
end

return M
