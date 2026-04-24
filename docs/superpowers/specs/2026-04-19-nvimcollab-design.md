# NvimCollab Design Spec

Real-time collaborative editing between Neovim and browser-based editors using Yjs CRDTs.

## Problem

Google Docs does not expose a real-time editing protocol. There is no way to build true live co-editing from Neovim against Google Docs. Instead, we build our own collaboration layer where Neovim users and browser users edit the same document simultaneously via CRDTs.

## Architecture

```
┌─────────────┐     WebSocket     ┌──────────────┐     WebSocket     ┌─────────────────┐
│   Neovim    │ ◄──────────────► │  Yjs Server  │ ◄──────────────► │  Browser Editor  │
│  (Lua+Node) │                   │ (y-websocket)│                   │  (TipTap + Yjs)  │
└─────────────┘                   └──────────────┘                   └─────────────────┘
```

All three components communicate over WebSocket. The Yjs server is the sync hub — it holds the authoritative CRDT document state and relays updates between clients.

## Components

### 1. Yjs WebSocket Server

**Tech:** Node.js, `y-websocket` package.

**Responsibilities:**
- Host named document rooms (each room = one collaborative document)
- Relay Yjs sync/awareness updates between connected clients
- No persistence in prototype (in-memory only)

**Interface:**
- `ws://localhost:4455/:roomName` — clients connect with a room name in the URL path

**Implementation:** Essentially the `y-websocket` server binary with a custom port. Under 20 lines of configuration.

### 2. Web Editor (Browser Client)

**Tech:** Vite + vanilla JS, CodeMirror 6, `y-websocket` provider, `y-codemirror.next` bindings.

**Responsibilities:**
- Render a Markdown-friendly text editor in the browser
- Connect to a Yjs room via WebSocket
- Show remote cursor positions and names via Yjs awareness protocol
- Room selection via URL parameter (`?room=my-doc`)

**Key decisions:**
- Use CodeMirror 6 (not TipTap) as the browser editor. CodeMirror is a code/plain-text editor with native Yjs bindings (`y-codemirror.next`). This avoids the rich-text mismatch — both Neovim and the browser operate on identical plain text. Markdown syntax highlighting comes free via CodeMirror's Markdown language mode.
- Awareness protocol shows who is connected and their cursor positions (CodeMirror's Yjs binding supports remote cursors out of the box).
- Minimal UI: editor area, connection status indicator, participant list.

**Interface:**
- `http://localhost:5173/?room=my-doc` — opens the editor for a given room

### 3. Neovim Plugin

**Tech:** Lua plugin that spawns a Node.js sidecar process. Communication between Lua and Node via stdout/stdin JSON-RPC.

**Responsibilities:**
- `:CollabJoin <room>` — connect current buffer to a named room
- `:CollabLeave` — disconnect from the room
- Capture local buffer changes via `nvim_buf_attach` on_bytes callback
- Convert buffer byte-level diffs to Y.Text operations (insert/delete at offset)
- Apply incoming Y.Text changes to the Neovim buffer without re-triggering the change listener
- Broadcast cursor position via Yjs awareness protocol

**Sidecar process (Node.js):**
- Maintains the Yjs Y.Doc and Y.Text instance
- Connects to the Yjs WebSocket server
- Receives local edits from Neovim (via stdin JSON messages), applies to Y.Text
- Observes Y.Text changes from remote peers, sends them to Neovim (via stdout JSON messages)

**Lua ↔ Node message protocol (JSON over stdio, newline-delimited):**

```
→ To Node:   {"type":"edit","offset":42,"delete":5,"insert":"hello"}
→ To Node:   {"type":"cursor","offset":42,"name":"mi"}
→ To Node:   {"type":"join","room":"my-doc","server":"ws://localhost:4455"}
→ To Node:   {"type":"leave"}

← From Node: {"type":"edit","offset":42,"delete":5,"insert":"hello"}
← From Node: {"type":"cursor","clientId":123,"offset":42,"name":"them"}
← From Node: {"type":"sync","content":"full document text"}
← From Node: {"type":"connected","room":"my-doc"}
← From Node: {"type":"disconnected"}
```

**Buffer ↔ Y.Text offset conversion:**

Neovim's `on_bytes` callback provides (start_row, start_col, byte_offset, old_end_row, old_end_col, old_byte_length, new_end_row, new_end_col, new_byte_length). The sidecar needs a single linear offset + delete length + insert text. The Lua side converts using `vim.api.nvim_buf_get_offset()` to map row/col to byte offset, then sends the linear offset, old byte length (delete), and the inserted text.

**Guarding against echo loops:**

When applying remote changes to the buffer, the plugin sets a flag (`self.applying_remote = true`) before calling `nvim_buf_set_text`. The `on_bytes` callback checks this flag and skips sending the edit back to the sidecar.

## Data Model

The shared document is a single `Y.Text` instance within a `Y.Doc`. The text content is plain Markdown. No rich-text attributes are stored in the CRDT — formatting lives in the Markdown syntax itself.

## Directory Structure

```
nvimcollab/
├── server/
│   ├── package.json
│   └── index.js              # y-websocket server entry
├── web/
│   ├── package.json
│   ├── vite.config.js
│   ├── index.html
│   └── src/
│       └── main.js           # TipTap + Yjs setup
├── nvim-plugin/
│   ├── lua/
│   │   └── nvimcollab/
│   │       └── init.lua       # Neovim commands, buffer attachment, sidecar management
│   ├── sidecar/
│   │   ├── package.json
│   │   └── index.js           # Node.js Yjs client, stdio JSON-RPC
│   └── plugin/
│       └── nvimcollab.lua     # Plugin registration (lazy.nvim compatible)
└── README.md
```

This lives as a new top-level directory in the miconfig repo, sibling to `nvim/` and `claude-config/`.

## User Flow

1. Start the server: `cd nvimcollab/server && node index.js`
2. Start the web UI: `cd nvimcollab/web && npx vite`
3. In Neovim: `:CollabJoin my-doc`
4. In browser: open `http://localhost:5173/?room=my-doc`
5. Both editors now show the same text and sync in real-time
6. `:CollabLeave` to disconnect

## Prototype Scope Boundaries

**In scope:**
- Single Y.Text document per room
- Real-time sync between Neovim and browser
- Cursor awareness (who is where)
- Multiple simultaneous rooms (by name)
- Connection/disconnection handling

**Out of scope (future):**
- Persistence (documents lost on server restart)
- Authentication / authorization
- Rich text formatting in browser
- Google Docs export
- File tree / multi-document management
- Deployment / HTTPS / production hosting
- User presence indicators beyond cursors

## Error Handling

- If the sidecar process crashes, Neovim shows an error message and the buffer continues to work locally (just not synced).
- If the WebSocket server is unreachable, both clients show a "disconnected" status and retry with exponential backoff.
- If the browser tab closes, other clients see the cursor disappear via awareness protocol.

## Dependencies

**Server:** `y-websocket`, `yjs`
**Web:** `vite`, `@codemirror/view`, `@codemirror/state`, `@codemirror/lang-markdown`, `yjs`, `y-websocket`, `y-codemirror.next`
**Neovim sidecar:** `yjs`, `y-websocket`, `ws`
