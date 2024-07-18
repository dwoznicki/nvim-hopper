local M = {}

-- function readOnly (t)
--   local proxy = {}
--   local mt = {       -- create metatable
--     __index = t,
--     __newindex = function (t,k,v)
--       error("attempt to update a read-only table", 2)
--     end
--   }
--   setmetatable(proxy, mt)
--   return proxy
-- end

local keymap_alpha = {
  "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
}
local keymap_numeric = {
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
}
local keymap_ergonomic = {
  "a", "s", "d", "f", "j", "k", "l", "q", "w", "e", "r", "t", "u", "i", "o", "p", "z", "x", "c", "v", "b", "n", "m", "g", "h", "y",
}

M.open_overlay = function()
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.ceil(ui.width * 0.3)
  local height = math.ceil(ui.height * 0.7)
  local options = {
    style = "minimal",
    relative = "editor",
    width = width,
    height = height,
    row = 1,
    col = math.ceil(ui.width - width) - 3,
    title = " Buffers ",
    border = "rounded",
  }
  local buf = vim.api.nvim_create_buf(false, true)
  -- vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"This is a fancy overlay!", "", "You can add more text here."})
  local win = vim.api.nvim_open_win(buf, true, options)
  -- vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<cr>", {noremap = true, silent = true})
  vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
  vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
  vim.api.nvim_set_option_value("swapfile", false, {buf = buf})
  vim.api.nvim_set_option_value("filetype", "bufferoverlay", {buf = buf})
  -- vim.api.nvim_set_option_value("readonly", true, {buf = buf})
  vim.api.nvim_buf_set_keymap(buf, "n", "<esc>", ":q<cr>", {noremap = true, silent = true})

  local buffer_keys = {}
  local i = 1
  for _, openbuf in ipairs(vim.api.nvim_list_bufs()) do
    if not vim.api.nvim_buf_is_loaded(openbuf) or vim.api.nvim_get_option_value("buftype", {buf = openbuf}) ~= "" then
      goto continue
    end
    local file_path = vim.api.nvim_buf_get_name(openbuf)
    -- local file_name = vim.fn.fnamemodify(file_path, ":t")
    local key = keymap_ergonomic[i]
    if key == nil then
      break
    end
    i = i + 1
    -- buffers[keymap] = {buf = b, file_path = file_path}
    -- vim.api.nvim_buf_set_keymap(buf, "n", key, "<cmd>b" .. buf .. "<cr>", {noremap = true, silent = false})
    vim.keymap.set(
      "n",
      key,
      function()
        M.close_overlay()
        vim.api.nvim_set_current_buf(openbuf)
      end,
      {noremap = true, silent = true, buffer = buf}
    )
    table.insert(buffer_keys, {key = key, buf = openbuf, file_path = file_path})
    ::continue::
  end

  table.sort(buffer_keys, function(a, b)
    return a.buf < b.buf
  end)

  -- local buf = M._overlay_buf
  -- local win = M._overlay_win
  -- local win_width = vim.api.nvim_win_get_width(win)
  local keymap_col_width = 1
  local file_path_col_width = math.floor(width - keymap_col_width - 5)

  local lines = {}
  -- table.insert(lines, string.format("%-".. keymap_col_width .. "s %-" .. col2_width .. "s %-" .. col3_width .. "s", "Buffer Number", "Full Path", "File Name"))
  -- print("?? " .. vim.inspect(buffers))
  -- table.insert(lines, "")
  for _, buffer_key in ipairs(buffer_keys) do
      table.insert(lines, string.format(" %-" .. keymap_col_width .. "s %-" .. file_path_col_width .. "s ", buffer_key.key, buffer_key.file_path))
  end
  -- table.insert(lines, "")
  -- table.insert(lines, string.rep(" ", win_width))

  -- vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"This is a fancy overlay!", "", "You can add more text here."})
  -- vim.api.nvim_set_option_value("readonly", false, {buf = buf})
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("readonly", true, {buf = buf})


  -- local on_key = vim.on_key(function(key)
  --   -- print("on_key" .. M._on_key_ns)
  --   if not M._on_key_ns then
  --     return
  --   end
  --   print("key " .. key)
  --   print("buffers " .. vim.inspect(M._buffers))
  --   local buffer = M._buffers[key]
  --   print("buffer " .. vim.inspect(buffer))
  --   if buffer then
  --     vim.api.nvim_set_current_buf(buffer.buf)
  --   end
  --   M.close_overlay()
  -- end, nil)
  -- vim.api.nvim_set_keymap("n", "<esc>", "", {noremap = true, silent = true})

  M._buffer_keys = buffer_keys
  M._overlay_buf = buf
  M._overlay_win = win

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = function()
      M._buffer_keys = nil
      M._overlay_buf = nil
      M._overlay_win = nil
    end,
  })

  -- M._on_key_ns = on_key
end

-- M.populate_overlay = function()
--   local buffers = {}
--   local i = 1
--   for _, buf in ipairs(vim.api.nvim_list_bufs()) do
--     if not vim.api.nvim_buf_is_loaded(buf) or vim.api.nvim_get_option_value("buftype", {buf = buf}) ~= "" then
--       goto continue
--     end
--     local file_path = vim.api.nvim_buf_get_name(buf)
--     -- local file_name = vim.fn.fnamemodify(file_path, ":t")
--     local keymap = keymap_ergonomic[i]
--     if keymap == nil then
--       break
--     end
--     i = i + 1
--     buffers[keymap] = {buf = buf, file_path = file_path}
--     -- table.insert(buffers, {buf = buf, file_path = file_path})
--     ::continue::
--   end
--
--   -- table.sort(buffers, function(a, b)
--   --   return a.buf < b.buf
--   -- end)
--
--   local buf = M._overlay_buf
--   local win = M._overlay_win
--   local win_width = vim.api.nvim_win_get_width(win)
--   local keymap_col_width = 1
--   local file_path_col_width = math.floor(win_width - keymap_col_width - 3)
--
--   local lines = {}
--   -- table.insert(lines, string.format("%-".. keymap_col_width .. "s %-" .. col2_width .. "s %-" .. col3_width .. "s", "Buffer Number", "Full Path", "File Name"))
--   -- print("?? " .. vim.inspect(buffers))
--   -- table.insert(lines, "")
--   for keymap, buffer in pairs(buffers) do
--       table.insert(lines, string.format(" %-" .. keymap_col_width .. "s %-" .. file_path_col_width .. "s ", keymap, buffer.file_path))
--   end
--   -- table.insert(lines, "")
--   -- table.insert(lines, string.rep(" ", win_width))
--
--   -- vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"This is a fancy overlay!", "", "You can add more text here."})
--   vim.api.nvim_set_option_value("readonly", false, {buf = buf})
--   vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
--   vim.api.nvim_set_option_value("readonly", true, {buf = buf})
--
--   M._buffers = buffers
-- end

M.close_overlay = function()
  if M._overlay_win and vim.api.nvim_win_is_valid(M._overlay_win) then
    vim.api.nvim_win_close(M._overlay_win, true)
  end
  -- if M._on_key_ns then
  --   vim.on_key(nil, M._on_key_ns)
  -- end
  -- M._on_key_ns = nil
end

-- local api = vim.api
-- local buf, win

-- M.open_floating_window = function()
--   buf = vim.api.nvim_create_buf(false, true)
--   local border_buf = vim.api.nvim_create_buf(false, true)
--
--   local ui = vim.api.nvim_list_uis()[1]
--   local width = math.ceil(ui.width * 0.6)
--   local height = math.ceil(ui.height * 0.4)
--   local row = math.ceil((ui.height - height) / 2)
--   local col = math.ceil((ui.width - width) / 2)
--
--   local border_opts = {
--     style = "minimal",
--     relative = "editor",
--     width = width + 2,
--     height = height + 2,
--     row = row - 1,
--     col = col - 1
--   }
--
--   local opts = {
--     style = "minimal",
--     relative = "editor",
--     width = width,
--     height = height,
--     row = row,
--     col = col
--   }
--
--   local border_title = " Buffer List "
--   local border_lines = { "╭" .. border_title .. string.rep("─", width - string.len(border_title)) .. "╮" }
--   local middle_line = "│" .. string.rep(" ", width) .. "│"
--   for _ = 1, height do
--     table.insert(border_lines, middle_line)
--   end
--   table.insert(border_lines, "╰" .. string.rep("─", width) .. "╯")
--   vim.api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)
--
--   local border_win = vim.api.nvim_open_win(border_buf, true, border_opts)
--   win = vim.api.nvim_open_win(buf, true, opts)
--   vim.api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "' .. border_buf)
--   vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", {noremap = true, silent = true})
--
--   -- vim.api.nvim_win_set_option(win, 'cursorline', true)
-- end
--
-- M.update_view = function()
--   -- vim.api.nvim_buf_set_option(buf, 'modifiable', true)
--
--   local ls = vim.fn.execute(':ls')
--   local result = {}
--
--   for buffer in string.gmatch(ls, "([^\r\n]*)") do
--     if string.match(buffer, "%d+") then
--       if string.match(buffer, '%d+.-(a).-".-"') == 'a' and string.match(buffer, '"(.-)"') ~= '[No Name]' then
--         buffer = string.match(buffer, '"(.-)"')
--         table.insert(result, "> " .. buffer)
--       else
--         buffer = string.match(buffer, '"(.-)"')
--         table.insert(result, buffer)
--       end
--     end
--   end
--
--   vim.api.nvim_buf_set_lines(buf, 0, -1, false, result)
--   vim.api.nvim_buf_set_option(buf, 'modifiable', false)
-- end
--
-- local function close_window()
--   api.nvim_win_close(win, true)
-- end
--
-- local function close_buffer()
--   local selected_line = api.nvim_get_current_line()
--
--   if string.match(selected_line, '^> ') then
--     selected_line = string.match(selected_line, '^> (.-)$')
--   end
--
--   local ls = vim.fn.execute(':ls')
--
--   for buffer in string.gmatch(ls, '([^\r\n]*)') do
--     if string.match(buffer, '%d+') and string.match(buffer, '"(.-)"') == selected_line then
--       if string.match(buffer, '%d+.-(a).-".-"') == 'a' then
--         close_window()
--         api.nvim_command('bd')
--       else
--         api.nvim_command('bd ' .. string.match(buffer, '%d+'))
--         update_view()
--       end
--     end
--   end
-- end
--
-- local function go_to_buffer()
--   local selected_line = api.nvim_get_current_line()
--
--   local ls = vim.fn.execute(':ls')
--
--   for buffer in string.gmatch(ls, '([^\r\n]*)') do
--     if string.match(buffer, '%d+') and string.match(buffer, '"(.-)"') == selected_line then
--       close_window()
--       api.nvim_command('b ' .. string.match(buffer, '%d+'))
--     end
--   end
-- end
--
-- local function move_cursor()
--   local new_pos = math.max(4, api.nvim_win_get_cursor(win)[1] - 1)
--   api.nvim_win_set_cursor(win, { new_pos, 0 })
-- end
--
-- local function set_mappings()
--   local mappings = {
--     ['<esc>'] = 'close_window()',
--     ['<cr>'] = 'go_to_buffer()',
--     l = 'go_to_buffer()',
--     h = 'close_buffer()',
--     d = 'close_buffer()',
--     q = 'close_window()',
--   }
--
--   for k, v in pairs(mappings) do
--     api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"nvim-bufferlist".' .. v .. '<cr>', {
--       nowait = true, noremap = true, silent = true
--     })
--   end
--
--   local other_chars = {
--     'a', 'b', 'c', 'e', 'f', 'g', 'i', 'n', 'o', 'p', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
--   }
--
--   for _, v in ipairs(other_chars) do
--     api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
--     api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
--     api.nvim_buf_set_keymap(buf, 'n', '<c-' .. v .. '>', '', { nowait = true, noremap = true, silent = true })
--   end
-- end
--
-- local function bufferlist()
--   open_window()
--   update_view()
--   set_mappings()
--   api.nvim_win_set_cursor(win, { 1, 0 })
-- end

-- return {
--   bufferlist = bufferlist,
--   update_view = update_view,
--   go_to_buffer = go_to_buffer,
--   close_buffer = close_buffer,
--   move_cursor = move_cursor,
--   close_window = close_window
-- }

M.setup = function()
  -- vim.api.nvim_add_user_command("FancyOverlay", M.create_floating_window)
  vim.api.nvim_create_user_command(
    "FancyOverlay",
    M.open_overlay,
    {nargs = 0}
  )
  vim.api.nvim_create_user_command(
    "FancyOverlayClose",
    M.close_overlay,
    {nargs = 0}
  )
end

return M
