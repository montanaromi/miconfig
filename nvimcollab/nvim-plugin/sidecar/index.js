// nvimcollab/nvim-plugin/sidecar/index.js
import * as Y from 'yjs'
import { WebsocketProvider } from 'y-websocket'
import { createRequire } from 'module'
import readline from 'readline'

const require = createRequire(import.meta.url)
const WebSocket = require('ws')

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
