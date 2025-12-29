import { useState, useEffect } from 'react'

interface Request {
  id: string
  method: string
  path: string
  statusCode: number
  duration: number
  timestamp: Date
  requestHeaders: Record<string, string>
  requestBody?: string
  responseHeaders: Record<string, string>
  responseBody?: string
  matchedRoute?: string
  matchedTarget?: string
}

function App() {
  const [requests, setRequests] = useState<Request[]>([])
  const [selected, setSelected] = useState<Request | null>(null)
  const [connected, setConnected] = useState(false)
  const [reconnectCounter, setReconnectCounter] = useState(0)

  // Load historical requests on page load
  useEffect(() => {
    fetch('/api/requests')
      .then(r => r.json())
      .then(data => setRequests(data))
      .catch(console.error)
  }, [])

  useEffect(() => {
    // Connect to inspector WebSocket
    const ws = new WebSocket(`ws://${window.location.host}/api/live`)

    ws.onopen = () => setConnected(true)
    ws.onclose = () => {
      setConnected(false)
      // Reconnect after 3 seconds
      setTimeout(() => {
        setReconnectCounter(prev => prev + 1)
      }, 3000)
    }

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data)
        if (data.type === 'request') {
          setRequests(prev => [data.request, ...prev].slice(0, 1000))
        }
      } catch (e) {
        console.error('Failed to parse message:', e)
      }
    }

    return () => ws.close()
  }, [reconnectCounter])

  const statusColor = (code: number) => {
    if (code < 300) return 'text-green-500'
    if (code < 400) return 'text-blue-500'
    if (code < 500) return 'text-yellow-500'
    return 'text-red-500'
  }

  const copyAsCurl = (req: Request) => {
    const headers = Object.entries(req.requestHeaders)
      .map(([k, v]) => `-H '${k}: ${v}'`)
      .join(' ')
    const curl = `curl -X ${req.method} ${headers} '${window.location.origin}${req.path}'`
    navigator.clipboard.writeText(curl)
  }

  return (
    <div className="min-h-screen bg-gray-900 text-gray-100">
      {/* Header */}
      <header className="border-b border-gray-700 px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <h1 className="text-lg font-semibold">Sellia Inspector</h1>
          <span className={`text-xs px-2 py-0.5 rounded ${connected ? 'bg-green-600' : 'bg-red-600'}`}>
            {connected ? 'Live' : 'Disconnected'}
          </span>
        </div>
        <button
          onClick={async () => {
            await fetch('/api/requests/clear', { method: 'POST' })
            setRequests([])
          }}
          className="text-sm text-gray-400 hover:text-white"
        >
          Clear All
        </button>
      </header>

      <div className="flex h-[calc(100vh-57px)]">
        {/* Request List */}
        <div className="w-1/2 border-r border-gray-700 overflow-y-auto">
          {requests.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              Waiting for requests...
            </div>
          ) : (
            requests.map(req => (
              <div
                key={req.id}
                onClick={() => setSelected(req)}
                className={`px-4 py-2 border-b border-gray-800 cursor-pointer hover:bg-gray-800 ${
                  selected?.id === req.id ? 'bg-gray-800' : ''
                }`}
              >
                <div className="flex items-center gap-3">
                  <span className={`font-mono ${statusColor(req.statusCode)}`}>
                    {req.statusCode}
                  </span>
                  <span className="font-mono text-sm text-gray-300">
                    {req.method}
                  </span>
                  <span className="font-mono text-sm truncate flex-1">
                    {req.path}
                  </span>
                  {req.matchedTarget && (
                    <span className="text-xs text-gray-500 font-mono">
                      → {req.matchedTarget}
                    </span>
                  )}
                  <span className="text-xs text-gray-500">
                    {req.duration}ms
                  </span>
                </div>
              </div>
            ))
          )}
        </div>

        {/* Request Detail */}
        <div className="w-1/2 overflow-y-auto p-4">
          {selected ? (
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <h2 className="text-lg font-semibold">
                  {selected.method} {selected.path}
                </h2>
                <button
                  onClick={() => copyAsCurl(selected)}
                  className="text-sm px-3 py-1 bg-gray-700 rounded hover:bg-gray-600"
                >
                  Copy as curl
                </button>
              </div>

              <section>
                <h3 className="text-sm font-semibold text-gray-400 mb-2">Request Headers</h3>
                <pre className="bg-gray-800 p-3 rounded text-sm overflow-x-auto">
                  {JSON.stringify(selected.requestHeaders, null, 2)}
                </pre>
              </section>

              {selected.matchedRoute && (
                <section>
                  <h3 className="text-sm font-semibold text-gray-400 mb-2">Route</h3>
                  <div className="bg-gray-800 p-3 rounded text-sm font-mono">
                    {selected.matchedRoute} → {selected.matchedTarget}
                  </div>
                </section>
              )}

              {selected.requestBody && (
                <section>
                  <h3 className="text-sm font-semibold text-gray-400 mb-2">Request Body</h3>
                  <pre className="bg-gray-800 p-3 rounded text-sm overflow-x-auto">
                    {selected.requestBody}
                  </pre>
                </section>
              )}

              <section>
                <h3 className="text-sm font-semibold text-gray-400 mb-2">Response Headers</h3>
                <pre className="bg-gray-800 p-3 rounded text-sm overflow-x-auto">
                  {JSON.stringify(selected.responseHeaders, null, 2)}
                </pre>
              </section>

              {selected.responseBody && (
                <section>
                  <h3 className="text-sm font-semibold text-gray-400 mb-2">Response Body</h3>
                  <pre className="bg-gray-800 p-3 rounded text-sm overflow-x-auto whitespace-pre-wrap">
                    {selected.responseBody}
                  </pre>
                </section>
              )}
            </div>
          ) : (
            <div className="h-full flex items-center justify-center text-gray-500">
              Select a request to view details
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default App
