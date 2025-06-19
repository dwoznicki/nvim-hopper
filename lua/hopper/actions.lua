local M = {}

function M.choose_keymap()
  local project = "x"
  local path = require("hopper.filepath").get_path_from_project_root(vim.api.nvim_buf_get_name(0))
  local datastore = require("hopper.db").datastore()
  local existing_mapping = datastore:get_mapping_by_path(project, path)
  local existing_keymap = nil ---@type string | nil
  if existing_mapping ~= nil then
    existing_keymap = existing_mapping.keymap
  end
  local keymap_float = require("hopper.view.keymap_float").float()
  keymap_float:open(project, path, existing_keymap)
end

function M.open_file_hopper()
  local project = "x"
  local datastore = require("hopper.db").datastore()
  local mappings = datastore:list_mappings(project)
  local mappings_float = require("hopper.view.mappings_float").float()
  mappings_float:open(project, mappings)
end

return M

-- local state = require("hopper.state")
-- local view = require("hopper.view")
-- local buffer = require("hopper.buffer")
--
-- local M = {}
--
-- ---Open the floating window.
-- function M.open()
--   if state.current.floating_window ~= nil and state.current.floating_window:is_open() then
--     state.current.floating_window:focus()
--     return
--   end
--
--   -- Track buffer state before the cursor enters the floating window.
--   state.set_prior_current_buf()
--   state.set_prior_alternate_buf()
--   buffer.BufferList.create()
--   local float = view.FloatingWindow.open()
--   local buftable = view.BufferTable.attach(float)
--   buftable:draw()
--   buftable:cursor_to_buf(state.get_prior_current_buf())
--   local statline = view.StatusLine.attach(float)
--   state.get_mode_manager():set_mode(state.get_config().default_mode)
-- end
--
-- function M.close()
--   if state.current.floating_window ~= nil or not state.current.floating_window:is_open() then
--     return
--   end
--   state.current.floating_window:close()
-- end
--
-- -- function M.delete_other_buffers()
-- --   M.close()
-- --   local curbuf = vim.api.nvim_get_current_buf()
-- --   local num_closed = 0
-- --   for _, openbuf in ipairs(vim.api.nvim_list_bufs()) do
-- --     if not vim.api.nvim_buf_is_loaded(openbuf) or vim.api.nvim_get_option_value("buftype", {buf = openbuf}) ~= "" then
-- --       goto continue
-- --     end
-- --     if openbuf == curbuf then
-- --       goto continue
-- --     end
-- --     vim.api.nvim_buf_delete(openbuf, {})
-- --     num_closed = num_closed + 1
-- --     ::continue::
-- --   end
-- --   print(num_closed .. " buffers closed")
-- -- end
--
-- return M
