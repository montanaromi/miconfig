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
