# NvimCollab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real-time collaborative editor connecting Neovim and browser clients via Yjs CRDTs.

**Architecture:** Three components — a y-websocket relay server, a CodeMirror 6 web editor with Yjs bindings, and a Neovim plugin with a Node.js sidecar that bridges buffer changes to Y.Text operations. All communicate over WebSocket through named rooms.

**Tech Stack:** Node.js, yjs, y-websocket, CodeMirror 6, y-codemirror.next, Neovim Lua API, Vite

---

## File Structure

```
nvimcollab/
├── server/
│   ├── package.json              # yjs + y-websocket deps
│   └── index.js                  # y-websocket server on port 4455
├── web/
│   ├── package.json              # codemirror + yjs deps
│   ├── vite.config.js            # dev server config
│   ├── index.html                # shell HTML with #editor div
│   └── src/
│       └── main.js               # CodeMirror + Yjs setup, awareness, status UI
├── nvim-plugin/
│   ├── lua/
│   │   └── nvimcollab/
│   │       └── init.lua          # Lua module: sidecar lifecycle, buffer attach, commands
│   ├── sidecar/
│   │   ├── package.json          # yjs + y-websocket + ws deps
│   │   └── index.js              # Node process: Yjs client, stdio JSON protocol
│   └── plugin/
│       └── nvimcollab.lua        # Plugin registration file for lazy.nvim
```

---

### Task 1: Yjs WebSocket Server

**Files:**
- Create: `nvimcollab/server/package.json`
- Create: `nvimcollab/server/index.js`

- [ ] **Step 1: Create package.json**

```json
{
  "name": "nvimcollab-server",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "dependencies": {
    "yjs": "^13.6.0",
    "y-websocket": "^2.0.0"
  }
}
```

- [ ] **Step 2: Create server entry**

```js
// nvimcollab/server/index.js
import { WebSocketServer } from 'ws'
import { setupWSConnection } from 'y-websocket/bin/utils'

const PORT = 4455
const wss = new WebSocketServer({ port: PORT })

wss.on('connection', (ws, req) => {
  const room = req.url.slice(1) || 'default'
  console.log(`[nvimcollab] client joined room: ${room}`)
  setupWSConnection(ws, req, { docName: room })
})

wss.on('listening', () => {
  console.log(`[nvimcollab] server listening on ws://localhost:${PORT}`)
})
```

- [ ] **Step 3: Install dependencies and verify server starts**

Run:
```bash
cd nvimcollab/server && npm install && node index.js &
sleep 1 && kill %1
```
Expected: `[nvimcollab] server listening on ws://localhost:4455` printed to stdout, process exits cleanly.

- [ ] **Step 4: Commit**

```bash
git add nvimcollab/server/
git commit -m "feat(nvimcollab): add yjs websocket relay server"
```

---

### Task 2: Web Editor — Project Scaffold

**Files:**
- Create: `nvimcollab/web/package.json`
- Create: `nvimcollab/web/vite.config.js`
- Create: `nvimcollab/web/index.html`

- [ ] **Step 1: Create package.json**

```json
{
  "name": "nvimcollab-web",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build"
  },
  "dependencies": {
    "@codemirror/lang-markdown": "^6.3.0",
    "@codemirror/state": "^6.4.0",
    "@codemirror/view": "^6.35.0",
    "@codemirror/theme-one-dark": "^6.0.0",
    "codemirror": "^6.0.0",
    "y-codemirror.next": "^0.3.5",
    "y-websocket": "^2.0.0",
    "yjs": "^13.6.0"
  },
  "devDependencies": {
    "vite": "^6.0.0"
  }
}
```

- [ ] **Step 2: Create vite.config.js**

```js
// nvimcollab/web/vite.config.js
import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    port: 5173,
  },
})
```

- [ ] **Step 3: Create index.html**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>NvimCollab</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: system-ui, sans-serif; background: #1e1e2e; color: #cdd6f4; height: 100vh; display: flex; flex-direction: column; }
    #header { padding: 8px 16px; background: #181825; display: flex; justify-content: space-between; align-items: center; font-size: 14px; border-bottom: 1px solid #313244; }
    #header .room { color: #89b4fa; }
    #header .status { font-size: 12px; }
    #header .status.connected { color: #a6e3a1; }
    #header .status.disconnected { color: #f38ba8; }
    #participants { display: flex; gap: 8px; }
    #participants .participant { font-size: 12px; padding: 2px 8px; border-radius: 4px; background: #313244; }
    #editor { flex: 1; overflow: auto; }
    .cm-editor { height: 100%; }
    .cm-scroller { overflow: auto; }
    /* Remote cursor styling */
    .cm-ySelectionInfo { font-size: 11px; padding: 1px 4px; border-radius: 2px; font-family: system-ui; }
  </style>
</head>
<body>
  <div id="header">
    <span>nvimcollab — <span class="room" id="room-name">default</span></span>
    <div id="participants"></div>
    <span class="status disconnected" id="status">disconnected</span>
  </div>
  <div id="editor"></div>
  <script type="module" src="/src/main.js"></script>
</body>
</html>
```

- [ ] **Step 4: Install dependencies**

Run:
```bash
cd nvimcollab/web && npm install
```
Expected: `node_modules/` created, no errors.

- [ ] **Step 5: Commit**

```bash
git add nvimcollab/web/package.json nvimcollab/web/vite.config.js nvimcollab/web/index.html
git commit -m "feat(nvimcollab): scaffold web editor project"
```

---

### Task 3: Web Editor — CodeMirror + Yjs Integration

**Files:**
- Create: `nvimcollab/web/src/main.js`

- [ ] **Step 1: Create main.js with CodeMirror + Yjs**

```js
// nvimcollab/web/src/main.js
import { EditorView, basicSetup } from 'codemirror'
import { markdown } from '@codemirror/lang-markdown'
import { EditorState } from '@codemirror/state'
import { oneDark } from '@codemirror/theme-one-dark'
import * as Y from 'yjs'
import { WebsocketProvider } from 'y-websocket'
import { yCollab } from 'y-codemirror.next'

const params = new URLSearchParams(window.location.search)
const room = params.get('room') || 'default'
const username = params.get('name') || `web-${Math.floor(Math.random() * 1000)}`
const serverUrl = params.get('server') || 'ws://localhost:4455'

// Display room name
document.getElementById('room-name').textContent = room

// Yjs setup
const ydoc = new Y.Doc()
const ytext = ydoc.getText('content')
const provider = new WebsocketProvider(serverUrl, room, ydoc)

// Awareness (cursor + user info)
const awareness = provider.awareness
awareness.setLocalStateField('user', {
  name: username,
  color: '#' + Math.floor(Math.random() * 0xffffff).toString(16).padStart(6, '0'),
  colorLight: '#' + Math.floor(Math.random() * 0xffffff).toString(16).padStart(6, '0') + '40',
})

// Connection status
const statusEl = document.getElementById('status')
provider.on('status', ({ status }) => {
  statusEl.textContent = status
  statusEl.className = `status ${status}`
})

// Participants list
const participantsEl = document.getElementById('participants')
awareness.on('change', () => {
  const states = Array.from(awareness.getStates().values())
  participantsEl.innerHTML = states
    .filter(s => s.user)
    .map(s => `<span class="participant" style="border-left: 3px solid ${s.user.color}">${s.user.name}</span>`)
    .join('')
})

// CodeMirror editor
new EditorView({
  parent: document.getElementById('editor'),
  state: EditorState.create({
    doc: ytext.toString(),
    extensions: [
      basicSetup,
      markdown(),
      oneDark,
      yCollab(ytext, awareness),
      EditorView.theme({
        '&': { height: '100%' },
        '.cm-scroller': { overflow: 'auto' },
      }),
    ],
  }),
})
```

- [ ] **Step 2: Verify web editor loads and connects**

Start the server and web editor in parallel:
```bash
cd nvimcollab/server && node index.js &
cd nvimcollab/web && npx vite &
```
Open `http://localhost:5173/?room=test-room` in a browser. Expected: dark-themed editor loads, status shows "connected", room name shows "test-room". Open a second tab with `?room=test-room&name=user2` — typing in one tab should appear in the other in real time.

Kill background processes after verification:
```bash
kill %1 %2
```

- [ ] **Step 3: Commit**

```bash
git add nvimcollab/web/src/main.js
git commit -m "feat(nvimcollab): add codemirror yjs collaborative editor"
```

---

### Task 4: Neovim Sidecar — Node.js Yjs Client

**Files:**
- Create: `nvimcollab/nvim-plugin/sidecar/package.json`
- Create: `nvimcollab/nvim-plugin/sidecar/index.js`

- [ ] **Step 1: Create sidecar package.json**

```json
{
  "name": "nvimcollab-sidecar",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "dependencies": {
    "ws": "^8.18.0",
    "y-websocket": "^2.0.0",
    "yjs": "^13.6.0"
  }
}
```

- [ ] **Step 2: Create sidecar index.js**

This is the core bridge. It reads JSON messages from stdin (sent by Neovim Lua), applies them to Y.Text, and writes remote changes back to stdout.

```js
// nvimcollab/nvim-plugin/sidecar/index.js
import * as Y from 'yjs'
import { WebsocketProvider } from 'y-websocket'
import { default as WebSocket } from 'ws'
import readline from 'readline'

let ydoc = null
let ytext = null
let provider = null
let suppressLocal = false

// --- stdio JSON protocol ---
const rl = readline.createInterface({ input: process.stdin })

function send(msg) {
  process.stdout.write(JSON.stringify(msg) + '\n')
}

rl.on('line', (line) => {
  let msg
  try {
    msg = JSON.parse(line)
  } catch {
    return
  }

  if (msg.type === 'join') {
    join(msg.room, msg.server, msg.name || 'nvim')
  } else if (msg.type === 'leave') {
    leave()
  } else if (msg.type === 'edit') {
    applyLocalEdit(msg.offset, msg.delete, msg.insert)
  } else if (msg.type === 'cursor') {
    if (provider && provider.awareness) {
      provider.awareness.setLocalStateField('user', {
        name: msg.name || 'nvim',
        color: '#89b4fa',
        colorLight: '#89b4fa40',
      })
      provider.awareness.setLocalStateField('cursor', { offset: msg.offset })
    }
  }
})

// --- Yjs lifecycle ---
function join(room, server, name) {
  leave()

  ydoc = new Y.Doc()
  ytext = ydoc.getText('content')

  provider = new WebsocketProvider(server, room, ydoc, { WebSocketPolyfill: WebSocket })

  provider.awareness.setLocalStateField('user', {
    name: name,
    color: '#89b4fa',
    colorLight: '#89b4fa40',
  })

  provider.on('status', ({ status }) => {
    send({ type: status === 'connected' ? 'connected' : 'disconnected', room })
  })

  provider.on('sync', (synced) => {
    if (synced) {
      send({ type: 'sync', content: ytext.toString() })
    }
  })

  // Observe remote changes
  ytext.observe((event) => {
    if (suppressLocal) return

    let offset = 0
    for (const delta of event.delta) {
      if (delta.retain != null) {
        offset += delta.retain
      } else if (delta.insert != null) {
        send({ type: 'edit', offset, delete: 0, insert: delta.insert })
        offset += delta.insert.length
      } else if (delta.delete != null) {
        send({ type: 'edit', offset, delete: delta.delete, insert: '' })
      }
    }
  })
}

function leave() {
  if (provider) {
    provider.destroy()
    provider = null
  }
  if (ydoc) {
    ydoc.destroy()
    ydoc = null
    ytext = null
  }
  send({ type: 'disconnected' })
}

function applyLocalEdit(offset, deleteCount, insertText) {
  if (!ytext) return
  suppressLocal = true
  ydoc.transact(() => {
    if (deleteCount > 0) {
      ytext.delete(offset, deleteCount)
    }
    if (insertText.length > 0) {
      ytext.insert(offset, insertText)
    }
  })
  suppressLocal = false
}

// Handle process exit
process.on('SIGTERM', () => { leave(); process.exit(0) })
process.on('SIGINT', () => { leave(); process.exit(0) })
```

- [ ] **Step 3: Install dependencies and verify sidecar starts**

Run:
```bash
cd nvimcollab/nvim-plugin/sidecar && npm install
echo '{"type":"join","room":"test","server":"ws://localhost:4455","name":"nvim"}' | timeout 3 node index.js || true
```
Expected: If no server is running, it should print `{"type":"disconnected"}` (initial leave cleanup). If the server is running, it should print `{"type":"connected","room":"test"}` followed by `{"type":"sync","content":""}`.

- [ ] **Step 5: Commit**

```bash
git add nvimcollab/nvim-plugin/sidecar/
git commit -m "feat(nvimcollab): add node.js yjs sidecar for neovim bridge"
```

---

### Task 5: Neovim Plugin — Lua Module

**Files:**
- Create: `nvimcollab/nvim-plugin/lua/nvimcollab/init.lua`

- [ ] **Step 1: Create the Lua module**

This module manages the sidecar process lifecycle, attaches to buffers, and bridges edits.

```lua
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
```

- [ ] **Step 2: Commit**

```bash
git add nvimcollab/nvim-plugin/lua/nvimcollab/init.lua
git commit -m "feat(nvimcollab): add neovim lua module for sidecar bridge"
```

---

### Task 6: Neovim Plugin — lazy.nvim Registration

**Files:**
- Create: `nvimcollab/nvim-plugin/plugin/nvimcollab.lua`

- [ ] **Step 1: Create the plugin registration file**

This file is loaded by lazy.nvim's plugin discovery. It calls `setup()` to register user commands.

```lua
-- nvimcollab/nvim-plugin/plugin/nvimcollab.lua
require("nvimcollab").setup()
```

- [ ] **Step 2: Add nvimcollab to the Neovim plugin list**

Edit `nvim/lua/plugins/extras.lua` to add the local plugin. lazy.nvim supports `dir` for local plugins:

Add the following entry to the returned table in `nvim/lua/plugins/extras.lua`:

```lua
  {
    dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h:h") .. "/nvimcollab/nvim-plugin",
    name = "nvimcollab",
    config = function()
      require("nvimcollab").setup({
        server_url = "ws://localhost:4455",
        username = vim.env.USER or "nvim",
      })
    end,
  },
```

This resolves the path relative to the miconfig repo root (up from `nvim/lua/plugins/` to repo root, then into `nvimcollab/nvim-plugin`).

- [ ] **Step 3: Commit**

```bash
git add nvimcollab/nvim-plugin/plugin/nvimcollab.lua nvim/lua/plugins/extras.lua
git commit -m "feat(nvimcollab): register plugin with lazy.nvim"
```

---

### Task 7: Integration Test — End-to-End Sync

**Files:** None created — this is a manual verification task.

- [ ] **Step 1: Install all dependencies**

```bash
cd nvimcollab/server && npm install
cd ../nvim-plugin/sidecar && npm install
cd ../../web && npm install
```

- [ ] **Step 2: Start the server**

```bash
cd nvimcollab/server && node index.js
```
Expected: `[nvimcollab] server listening on ws://localhost:4455`

- [ ] **Step 3: Start the web editor**

In a new terminal:
```bash
cd nvimcollab/web && npx vite
```
Expected: Vite dev server starts on `http://localhost:5173`

- [ ] **Step 4: Open the web editor**

Open `http://localhost:5173/?room=test&name=browser-user` in a browser. Expected: CodeMirror editor loads, status shows "connected", participant shows "browser-user".

- [ ] **Step 5: Connect Neovim**

Open Neovim and run:
```vim
:CollabJoin test
```
Expected: `[nvimcollab] connected to room: test` notification appears. If the browser already has text, the Neovim buffer should be replaced with that text.

- [ ] **Step 6: Verify bidirectional sync**

1. Type text in the browser editor — it should appear in the Neovim buffer within ~100ms.
2. Type text in Neovim — it should appear in the browser editor within ~100ms.
3. Both users should appear in the browser's participant list.

- [ ] **Step 7: Verify disconnect**

Run `:CollabLeave` in Neovim. Expected: the browser's participant list no longer shows the Neovim user. The Neovim buffer remains with the last synced content.

- [ ] **Step 8: Commit any fixes needed**

If any bugs were found and fixed during integration testing:
```bash
git add -A && git commit -m "fix(nvimcollab): integration test fixes"
```
