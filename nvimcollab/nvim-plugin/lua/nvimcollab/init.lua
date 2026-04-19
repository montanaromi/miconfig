-- nvimcollab/nvim-plugin/lua/nvimcollab/init.lua
local M = {}

M.job_id = nil
M.attached_buf = nil
M.applying_remote = false
M.server_url = "ws://localhost:4455"
M.username = "nvim"

-- Resolve the sidecar script path relative to this plugin
local function sidecar_path()
  local source = debug.getinfo(1, "S").source:sub(2) -- strip leading @
  local plugin_dir = vim.fn.fnamemodify(source, ":h:h:h") -- up from lua/nvimcollab/ to nvim-plugin/
  return plugin_dir .. "/sidecar/index.js"
end

-- Send a JSON message to the sidecar via stdin
local function send(msg)
  if M.job_id then
    vim.fn.chansend(M.job_id, vim.fn.json_encode(msg) .. "\n")
  end
end

-- Handle messages from sidecar (stdout)
local function on_stdout(_, data, _)
  for _, line in ipairs(data) do
    if line == "" then goto continue end
    local ok, msg = pcall(vim.fn.json_decode, line)
    if not ok then goto continue end

    if msg.type == "connected" then
      vim.schedule(function()
        vim.notify("[nvimcollab] connected to room: " .. (msg.room or "?"), vim.log.levels.INFO)
      end)

    elseif msg.type == "disconnected" then
      vim.schedule(function()
        vim.notify("[nvimcollab] disconnected", vim.log.levels.WARN)
      end)

    elseif msg.type == "sync" then
      vim.schedule(function()
        if not M.attached_buf or not vim.api.nvim_buf_is_valid(M.attached_buf) then return end
        M.applying_remote = true
        local lines = vim.split(msg.content, "\n", { plain = true })
        vim.api.nvim_buf_set_lines(M.attached_buf, 0, -1, false, lines)
        M.applying_remote = false
      end)

    elseif msg.type == "edit" then
      vim.schedule(function()
        if not M.attached_buf or not vim.api.nvim_buf_is_valid(M.attached_buf) then return end
        M.applying_remote = true
        apply_remote_edit(msg.offset, msg.delete, msg.insert)
        M.applying_remote = false
      end)
    end

    ::continue::
  end
end

-- Convert a byte offset to (row, col) in the buffer
local function offset_to_pos(buf, offset)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local remaining = offset
  for i, line in ipairs(lines) do
    local line_len = #line + 1 -- +1 for newline
    if remaining < line_len then
      return i - 1, remaining
    end
    remaining = remaining - line_len
  end
  -- Past end of buffer
  local last = #lines
  return last - 1, #(lines[last] or "")
end

-- Apply a remote edit (offset-based) to the buffer
function apply_remote_edit(offset, delete_count, insert_text)
  local buf = M.attached_buf
  if not buf then return end

  local start_row, start_col = offset_to_pos(buf, offset)

  if delete_count > 0 then
    local end_row, end_col = offset_to_pos(buf, offset + delete_count)
    vim.api.nvim_buf_set_text(buf, start_row, start_col, end_row, end_col, {})
  end

  if insert_text and #insert_text > 0 then
    local insert_lines = vim.split(insert_text, "\n", { plain = true })
    vim.api.nvim_buf_set_text(buf, start_row, start_col, start_row, start_col, insert_lines)
  end
end

-- Buffer on_bytes callback — captures local edits and sends to sidecar
local function on_bytes(_, buf, _, start_row, start_col, byte_offset, old_end_row, old_end_col, old_byte_len, new_end_row, new_end_col, new_byte_len)
  if M.applying_remote then return end

  -- Extract the inserted text from the buffer
  local insert_text = ""
  if new_byte_len > 0 then
    local end_row = start_row + new_end_row
    local end_col
    if new_end_row == 0 then
      end_col = start_col + new_end_col
    else
      end_col = new_end_col
    end
    local ok, lines = pcall(vim.api.nvim_buf_get_text, buf, start_row, start_col, end_row, end_col, {})
    if ok then
      insert_text = table.concat(lines, "\n")
    end
  end

  send({
    type = "edit",
    offset = byte_offset,
    delete = old_byte_len,
    insert = insert_text,
  })
end

-- Start the sidecar process
local function start_sidecar()
  if M.job_id then return end

  local script = sidecar_path()
  M.job_id = vim.fn.jobstart({ "node", script }, {
    on_stdout = on_stdout,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.schedule(function()
            vim.notify("[nvimcollab] sidecar: " .. line, vim.log.levels.DEBUG)
          end)
        end
      end
    end,
    on_exit = function(_, code)
      M.job_id = nil
      if code ~= 0 then
        vim.schedule(function()
          vim.notify("[nvimcollab] sidecar exited with code " .. code, vim.log.levels.ERROR)
        end)
      end
    end,
    stdout_buffered = false,
  })
end

-- Stop the sidecar process
local function stop_sidecar()
  if M.job_id then
    send({ type = "leave" })
    vim.fn.jobstop(M.job_id)
    M.job_id = nil
  end
end

-- :CollabJoin <room>
function M.join(room)
  room = room or "default"
  start_sidecar()

  M.attached_buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_attach(M.attached_buf, false, {
    on_bytes = on_bytes,
  })

  send({
    type = "join",
    room = room,
    server = M.server_url,
    name = M.username,
  })
end

-- :CollabLeave
function M.leave()
  send({ type = "leave" })

  M.attached_buf = nil
  stop_sidecar()
end

-- Setup function (called from plugin registration)
function M.setup(opts)
  opts = opts or {}
  M.server_url = opts.server_url or M.server_url
  M.username = opts.username or M.username

  vim.api.nvim_create_user_command("CollabJoin", function(cmd)
    M.join(cmd.args ~= "" and cmd.args or nil)
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("CollabLeave", function()
    M.leave()
  end, {})
end

return M
