// nvimcollab/server/index.js
import { createRequire } from 'module'
const require = createRequire(import.meta.url)
const { Server: WebSocketServer } = require('ws')
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
