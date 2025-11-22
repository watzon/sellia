server.js
```
1 | import log from 'book';
2 | import Koa from 'koa';
3 | import tldjs from 'tldjs';
4 | import Debug from 'debug';
5 | import http from 'http';
6 | import { hri } from 'human-readable-ids';
7 | import Router from 'koa-router';
8 | 
9 | import ClientManager from './lib/ClientManager';
10 | 
11 | const debug = Debug('localtunnel:server');
12 | 
13 | export default function(opt) {
14 |     opt = opt || {};
15 | 
16 |     const validHosts = (opt.domain) ? [opt.domain] : undefined;
17 |     const myTldjs = tldjs.fromUserSettings({ validHosts });
18 |     const landingPage = opt.landing || 'https://localtunnel.github.io/www/';
19 | 
20 |     function GetClientIdFromHostname(hostname) {
21 |         return myTldjs.getSubdomain(hostname);
22 |     }
23 | 
24 |     const manager = new ClientManager(opt);
25 | 
26 |     const schema = opt.secure ? 'https' : 'http';
27 | 
28 |     const app = new Koa();
29 |     const router = new Router();
30 | 
31 |     router.get('/api/status', async (ctx, next) => {
32 |         const stats = manager.stats;
33 |         ctx.body = {
34 |             tunnels: stats.tunnels,
35 |             mem: process.memoryUsage(),
36 |         };
37 |     });
38 | 
39 |     router.get('/api/tunnels/:id/status', async (ctx, next) => {
40 |         const clientId = ctx.params.id;
41 |         const client = manager.getClient(clientId);
42 |         if (!client) {
43 |             ctx.throw(404);
44 |             return;
45 |         }
46 | 
47 |         const stats = client.stats();
48 |         ctx.body = {
49 |             connected_sockets: stats.connectedSockets,
50 |         };
51 |     });
52 | 
53 |     app.use(router.routes());
54 |     app.use(router.allowedMethods());
55 | 
56 |     // root endpoint
57 |     app.use(async (ctx, next) => {
58 |         const path = ctx.request.path;
59 | 
60 |         // skip anything not on the root path
61 |         if (path !== '/') {
62 |             await next();
63 |             return;
64 |         }
65 | 
66 |         const isNewClientRequest = ctx.query['new'] !== undefined;
67 |         if (isNewClientRequest) {
68 |             const reqId = hri.random();
69 |             debug('making new client with id %s', reqId);
70 |             const info = await manager.newClient(reqId);
71 | 
72 |             const url = schema + '://' + info.id + '.' + ctx.request.host;
73 |             info.url = url;
74 |             ctx.body = info;
75 |             return;
76 |         }
77 | 
78 |         // no new client request, send to landing page
79 |         ctx.redirect(landingPage);
80 |     });
81 | 
82 |     // anything after the / path is a request for a specific client name
83 |     // This is a backwards compat feature
84 |     app.use(async (ctx, next) => {
85 |         const parts = ctx.request.path.split('/');
86 | 
87 |         // any request with several layers of paths is not allowed
88 |         // rejects /foo/bar
89 |         // allow /foo
90 |         if (parts.length !== 2) {
91 |             await next();
92 |             return;
93 |         }
94 | 
95 |         const reqId = parts[1];
96 | 
97 |         // limit requested hostnames to 63 characters
98 |         if (! /^(?:[a-z0-9][a-z0-9\-]{4,63}[a-z0-9]|[a-z0-9]{4,63})$/.test(reqId)) {
99 |             const msg = 'Invalid subdomain. Subdomains must be lowercase and between 4 and 63 alphanumeric characters.';
100 |             ctx.status = 403;
101 |             ctx.body = {
102 |                 message: msg,
103 |             };
104 |             return;
105 |         }
106 | 
107 |         debug('making new client with id %s', reqId);
108 |         const info = await manager.newClient(reqId);
109 | 
110 |         const url = schema + '://' + info.id + '.' + ctx.request.host;
111 |         info.url = url;
112 |         ctx.body = info;
113 |         return;
114 |     });
115 | 
116 |     const server = http.createServer();
117 | 
118 |     const appCallback = app.callback();
119 | 
120 |     server.on('request', (req, res) => {
121 |         // without a hostname, we won't know who the request is for
122 |         const hostname = req.headers.host;
123 |         if (!hostname) {
124 |             res.statusCode = 400;
125 |             res.end('Host header is required');
126 |             return;
127 |         }
128 | 
129 |         const clientId = GetClientIdFromHostname(hostname);
130 |         if (!clientId) {
131 |             appCallback(req, res);
132 |             return;
133 |         }
134 | 
135 |         const client = manager.getClient(clientId);
136 |         if (!client) {
137 |             res.statusCode = 404;
138 |             res.end('404');
139 |             return;
140 |         }
141 | 
142 |         client.handleRequest(req, res);
143 |     });
144 | 
145 |     server.on('upgrade', (req, socket, head) => {
146 |         const hostname = req.headers.host;
147 |         if (!hostname) {
148 |             socket.destroy();
149 |             return;
150 |         }
151 | 
152 |         const clientId = GetClientIdFromHostname(hostname);
153 |         if (!clientId) {
154 |             socket.destroy();
155 |             return;
156 |         }
157 | 
158 |         const client = manager.getClient(clientId);
159 |         if (!client) {
160 |             socket.destroy();
161 |             return;
162 |         }
163 | 
164 |         client.handleUpgrade(req, socket);
165 |     });
166 | 
167 |     return server;
168 | };
```

server.test.js
```
1 | import request from 'supertest';
2 | import assert from 'assert';
3 | import { Server as WebSocketServer } from 'ws';
4 | import WebSocket from 'ws';
5 | import net from 'net';
6 | 
7 | import createServer from './server';
8 | 
9 | describe('Server', () => {
10 |     it('server starts and stops', async () => {
11 |         const server = createServer();
12 |         await new Promise(resolve => server.listen(resolve));
13 |         await new Promise(resolve => server.close(resolve));
14 |     });
15 | 
16 |     it('should redirect root requests to landing page', async () => {
17 |         const server = createServer();
18 |         const res = await request(server).get('/');
19 |         assert.equal('https://localtunnel.github.io/www/', res.headers.location);
20 |     });
21 | 
22 |     it('should support custom base domains', async () => {
23 |         const server = createServer({
24 |             domain: 'domain.example.com',
25 |         });
26 | 
27 |         const res = await request(server).get('/');
28 |         assert.equal('https://localtunnel.github.io/www/', res.headers.location);
29 |     });
30 | 
31 |     it('reject long domain name requests', async () => {
32 |         const server = createServer();
33 |         const res = await request(server).get('/thisdomainisoutsidethesizeofwhatweallowwhichissixtythreecharacters');
34 |         assert.equal(res.body.message, 'Invalid subdomain. Subdomains must be lowercase and between 4 and 63 alphanumeric characters.');
35 |     });
36 | 
37 |     it('should upgrade websocket requests', async () => {
38 |         const hostname = 'websocket-test';
39 |         const server = createServer({
40 |             domain: 'example.com',
41 |         });
42 |         await new Promise(resolve => server.listen(resolve));
43 | 
44 |         const res = await request(server).get('/websocket-test');
45 |         const localTunnelPort = res.body.port;
46 | 
47 |         const wss = await new Promise((resolve) => {
48 |             const wsServer = new WebSocketServer({ port: 0 }, () => {
49 |                 resolve(wsServer);
50 |             });
51 |         });
52 | 
53 |         const websocketServerPort = wss.address().port;
54 | 
55 |         const ltSocket = net.createConnection({ port: localTunnelPort });
56 |         const wsSocket = net.createConnection({ port: websocketServerPort });
57 |         ltSocket.pipe(wsSocket).pipe(ltSocket);
58 | 
59 |         wss.once('connection', (ws) => {
60 |             ws.once('message', (message) => {
61 |                 ws.send(message);
62 |             });
63 |         });
64 | 
65 |         const ws = new WebSocket('http://localhost:' + server.address().port, {
66 |             headers: {
67 |                 host: hostname + '.example.com',
68 |             }
69 |         });
70 | 
71 |         ws.on('open', () => {
72 |             ws.send('something');
73 |         });
74 | 
75 |         await new Promise((resolve) => {
76 |             ws.once('message', (msg) => {
77 |                 assert.equal(msg, 'something');
78 |                 resolve();
79 |             });
80 |         });
81 | 
82 |         wss.close();
83 |         await new Promise(resolve => server.close(resolve));
84 |     });
85 | 
86 |     it('should support the /api/tunnels/:id/status endpoint', async () => {
87 |         const server = createServer();
88 |         await new Promise(resolve => server.listen(resolve));
89 | 
90 |         // no such tunnel yet
91 |         const res = await request(server).get('/api/tunnels/foobar-test/status');
92 |         assert.equal(res.statusCode, 404);
93 | 
94 |         // request a new client called foobar-test
95 |         {
96 |             const res = await request(server).get('/foobar-test');
97 |         }
98 | 
99 |         {
100 |             const res = await request(server).get('/api/tunnels/foobar-test/status');
101 |             assert.equal(res.statusCode, 200);
102 |             assert.deepEqual(res.body, {
103 |                 connected_sockets: 0,
104 |             });
105 |         }
106 | 
107 |         await new Promise(resolve => server.close(resolve));
108 |     });
109 | });
```

lib/Client.js
```
1 | import http from 'http';
2 | import Debug from 'debug';
3 | import pump from 'pump';
4 | import EventEmitter from 'events';
5 | 
6 | // A client encapsulates req/res handling using an agent
7 | //
8 | // If an agent is destroyed, the request handling will error
9 | // The caller is responsible for handling a failed request
10 | class Client extends EventEmitter {
11 |     constructor(options) {
12 |         super();
13 | 
14 |         const agent = this.agent = options.agent;
15 |         const id = this.id = options.id;
16 | 
17 |         this.debug = Debug(`lt:Client[${this.id}]`);
18 | 
19 |         // client is given a grace period in which they can connect before they are _removed_
20 |         this.graceTimeout = setTimeout(() => {
21 |             this.close();
22 |         }, 1000).unref();
23 | 
24 |         agent.on('online', () => {
25 |             this.debug('client online %s', id);
26 |             clearTimeout(this.graceTimeout);
27 |         });
28 | 
29 |         agent.on('offline', () => {
30 |             this.debug('client offline %s', id);
31 | 
32 |             // if there was a previous timeout set, we don't want to double trigger
33 |             clearTimeout(this.graceTimeout);
34 | 
35 |             // client is given a grace period in which they can re-connect before they are _removed_
36 |             this.graceTimeout = setTimeout(() => {
37 |                 this.close();
38 |             }, 1000).unref();
39 |         });
40 | 
41 |         // TODO(roman): an agent error removes the client, the user needs to re-connect?
42 |         // how does a user realize they need to re-connect vs some random client being assigned same port?
43 |         agent.once('error', (err) => {
44 |             this.close();
45 |         });
46 |     }
47 | 
48 |     stats() {
49 |         return this.agent.stats();
50 |     }
51 | 
52 |     close() {
53 |         clearTimeout(this.graceTimeout);
54 |         this.agent.destroy();
55 |         this.emit('close');
56 |     }
57 | 
58 |     handleRequest(req, res) {
59 |         this.debug('> %s', req.url);
60 |         const opt = {
61 |             path: req.url,
62 |             agent: this.agent,
63 |             method: req.method,
64 |             headers: req.headers
65 |         };
66 | 
67 |         const clientReq = http.request(opt, (clientRes) => {
68 |             this.debug('< %s', req.url);
69 |             // write response code and headers
70 |             res.writeHead(clientRes.statusCode, clientRes.headers);
71 | 
72 |             // using pump is deliberate - see the pump docs for why
73 |             pump(clientRes, res);
74 |         });
75 | 
76 |         // this can happen when underlying agent produces an error
77 |         // in our case we 504 gateway error this?
78 |         // if we have already sent headers?
79 |         clientReq.once('error', (err) => {
80 |             // TODO(roman): if headers not sent - respond with gateway unavailable
81 |         });
82 | 
83 |         // using pump is deliberate - see the pump docs for why
84 |         pump(req, clientReq);
85 |     }
86 | 
87 |     handleUpgrade(req, socket) {
88 |         this.debug('> [up] %s', req.url);
89 |         socket.once('error', (err) => {
90 |             // These client side errors can happen if the client dies while we are reading
91 |             // We don't need to surface these in our logs.
92 |             if (err.code == 'ECONNRESET' || err.code == 'ETIMEDOUT') {
93 |                 return;
94 |             }
95 |             console.error(err);
96 |         });
97 | 
98 |         this.agent.createConnection({}, (err, conn) => {
99 |             this.debug('< [up] %s', req.url);
100 |             // any errors getting a connection mean we cannot service this request
101 |             if (err) {
102 |                 socket.end();
103 |                 return;
104 |             }
105 | 
106 |             // socket met have disconnected while we waiting for a socket
107 |             if (!socket.readable || !socket.writable) {
108 |                 conn.destroy();
109 |                 socket.end();
110 |                 return;
111 |             }
112 | 
113 |             // websocket requests are special in that we simply re-create the header info
114 |             // then directly pipe the socket data
115 |             // avoids having to rebuild the request and handle upgrades via the http client
116 |             const arr = [`${req.method} ${req.url} HTTP/${req.httpVersion}`];
117 |             for (let i=0 ; i < (req.rawHeaders.length-1) ; i+=2) {
118 |                 arr.push(`${req.rawHeaders[i]}: ${req.rawHeaders[i+1]}`);
119 |             }
120 | 
121 |             arr.push('');
122 |             arr.push('');
123 | 
124 |             // using pump is deliberate - see the pump docs for why
125 |             pump(conn, socket);
126 |             pump(socket, conn);
127 |             conn.write(arr.join('\r\n'));
128 |         });
129 |     }
130 | }
131 | 
132 | export default Client;
```

lib/Client.test.js
```
1 | import assert from 'assert';
2 | import http from 'http';
3 | import { Duplex } from 'stream';
4 | import WebSocket from 'ws';
5 | import net from 'net';
6 | 
7 | import Client from './Client';
8 | 
9 | class DummySocket extends Duplex {
10 |     constructor(options) {
11 |         super(options);
12 |     }
13 | 
14 |     _write(chunk, encoding, callback) {
15 |         callback();
16 |     }
17 | 
18 |     _read(size) {
19 |         this.push('HTTP/1.1 304 Not Modified\r\nX-Powered-By: dummy\r\n\r\n\r\n');
20 |         this.push(null);
21 |     }
22 | }
23 | 
24 | class DummyWebsocket extends Duplex {
25 |     constructor(options) {
26 |         super(options);
27 |         this.sentHeader = false;
28 |     }
29 | 
30 |     _write(chunk, encoding, callback) {
31 |         const str = chunk.toString();
32 |         // if chunk contains `GET / HTTP/1.1` -> queue headers
33 |         // otherwise echo back received data
34 |         if (str.indexOf('GET / HTTP/1.1') === 0) {
35 |             const arr = [
36 |                 'HTTP/1.1 101 Switching Protocols',
37 |                 'Upgrade: websocket',
38 |                 'Connection: Upgrade',
39 |             ];
40 |             this.push(arr.join('\r\n'));
41 |             this.push('\r\n\r\n');
42 |         }
43 |         else {
44 |             this.push(str);
45 |         }
46 |         callback();
47 |     }
48 | 
49 |     _read(size) {
50 |         // nothing to implement
51 |     }
52 | }
53 | 
54 | class DummyAgent extends http.Agent {
55 |     constructor() {
56 |         super();
57 |     }
58 | 
59 |     createConnection(options, cb) {
60 |         cb(null, new DummySocket());
61 |     }
62 | }
63 | 
64 | describe('Client', () => {
65 |     it('should handle request', async () => {
66 |         const agent = new DummyAgent();
67 |         const client = new Client({ agent });
68 | 
69 |         const server = http.createServer((req, res) => {
70 |             client.handleRequest(req, res);
71 |         });
72 | 
73 |         await new Promise(resolve => server.listen(resolve));
74 | 
75 |         const address = server.address();
76 |         const opt = {
77 |             host: 'localhost',
78 |             port: address.port,
79 |             path: '/',
80 |         };
81 | 
82 |         const res = await new Promise((resolve) => {
83 |             const req = http.get(opt, (res) => {
84 |                 resolve(res);
85 |             });
86 |             req.end();
87 |         });
88 |         assert.equal(res.headers['x-powered-by'], 'dummy');
89 |         server.close();
90 |     });
91 | 
92 |     it('should handle upgrade', async () => {
93 |         // need a websocket server and a socket for it
94 |         class DummyWebsocketAgent extends http.Agent {
95 |             constructor() {
96 |                 super();
97 |             }
98 | 
99 |             createConnection(options, cb) {
100 |                 cb(null, new DummyWebsocket());
101 |             }
102 |         }
103 | 
104 |         const agent = new DummyWebsocketAgent();
105 |         const client = new Client({ agent });
106 | 
107 |         const server = http.createServer();
108 |         server.on('upgrade', (req, socket, head) => {
109 |             client.handleUpgrade(req, socket);
110 |         });
111 | 
112 |         await new Promise(resolve => server.listen(resolve));
113 | 
114 |         const address = server.address();
115 | 
116 |         const netClient = await new Promise((resolve) => {
117 |             const newClient = net.createConnection({ port: address.port }, () => {
118 |                 resolve(newClient);
119 |             });
120 |         });
121 | 
122 |         const out = [
123 |             'GET / HTTP/1.1',
124 |             'Connection: Upgrade',
125 |             'Upgrade: websocket'
126 |         ];
127 | 
128 |         netClient.write(out.join('\r\n') + '\r\n\r\n');
129 | 
130 |         {
131 |             const data = await new Promise((resolve) => {
132 |                 netClient.once('data', (chunk) => {
133 |                     resolve(chunk.toString());
134 |                 });
135 |             });
136 |             const exp = [
137 |                 'HTTP/1.1 101 Switching Protocols',
138 |                 'Upgrade: websocket',
139 |                 'Connection: Upgrade',
140 |             ];
141 |             assert.equal(exp.join('\r\n') + '\r\n\r\n', data);
142 |         }
143 | 
144 |         {
145 |             netClient.write('foobar');
146 |             const data = await new Promise((resolve) => {
147 |                 netClient.once('data', (chunk) => {
148 |                     resolve(chunk.toString());
149 |                 });
150 |             });
151 |             assert.equal('foobar', data);
152 |         }
153 | 
154 |         netClient.destroy();
155 |         server.close();
156 |     });
157 | });
```

lib/ClientManager.js
```
1 | import { hri } from 'human-readable-ids';
2 | import Debug from 'debug';
3 | 
4 | import Client from './Client';
5 | import TunnelAgent from './TunnelAgent';
6 | 
7 | // Manage sets of clients
8 | //
9 | // A client is a "user session" established to service a remote localtunnel client
10 | class ClientManager {
11 |     constructor(opt) {
12 |         this.opt = opt || {};
13 | 
14 |         // id -> client instance
15 |         this.clients = new Map();
16 | 
17 |         // statistics
18 |         this.stats = {
19 |             tunnels: 0
20 |         };
21 | 
22 |         this.debug = Debug('lt:ClientManager');
23 | 
24 |         // This is totally wrong :facepalm: this needs to be per-client...
25 |         this.graceTimeout = null;
26 |     }
27 | 
28 |     // create a new tunnel with `id`
29 |     // if the id is already used, a random id is assigned
30 |     // if the tunnel could not be created, throws an error
31 |     async newClient(id) {
32 |         const clients = this.clients;
33 |         const stats = this.stats;
34 | 
35 |         // can't ask for id already is use
36 |         if (clients[id]) {
37 |             id = hri.random();
38 |         }
39 | 
40 |         const maxSockets = this.opt.max_tcp_sockets;
41 |         const agent = new TunnelAgent({
42 |             clientId: id,
43 |             maxSockets: 10,
44 |         });
45 | 
46 |         const client = new Client({
47 |             id,
48 |             agent,
49 |         });
50 | 
51 |         // add to clients map immediately
52 |         // avoiding races with other clients requesting same id
53 |         clients[id] = client;
54 | 
55 |         client.once('close', () => {
56 |             this.removeClient(id);
57 |         });
58 | 
59 |         // try/catch used here to remove client id
60 |         try {
61 |             const info = await agent.listen();
62 |             ++stats.tunnels;
63 |             return {
64 |                 id: id,
65 |                 port: info.port,
66 |                 max_conn_count: maxSockets,
67 |             };
68 |         }
69 |         catch (err) {
70 |             this.removeClient(id);
71 |             // rethrow error for upstream to handle
72 |             throw err;
73 |         }
74 |     }
75 | 
76 |     removeClient(id) {
77 |         this.debug('removing client: %s', id);
78 |         const client = this.clients[id];
79 |         if (!client) {
80 |             return;
81 |         }
82 |         --this.stats.tunnels;
83 |         delete this.clients[id];
84 |         client.close();
85 |     }
86 | 
87 |     hasClient(id) {
88 |         return !!this.clients[id];
89 |     }
90 | 
91 |     getClient(id) {
92 |         return this.clients[id];
93 |     }
94 | }
95 | 
96 | export default ClientManager;
```

lib/ClientManager.test.js
```
1 | import assert from 'assert';
2 | import net from 'net';
3 | 
4 | import ClientManager from './ClientManager';
5 | 
6 | describe('ClientManager', () => {
7 |     it('should construct with no tunnels', () => {
8 |         const manager = new ClientManager();
9 |         assert.equal(manager.stats.tunnels, 0);
10 |     });
11 | 
12 |     it('should create a new client with random id', async () => {
13 |         const manager = new ClientManager();
14 |         const client = await manager.newClient();
15 |         assert(manager.hasClient(client.id));
16 |         manager.removeClient(client.id);
17 |     });
18 | 
19 |     it('should create a new client with id', async () => {
20 |         const manager = new ClientManager();
21 |         const client = await manager.newClient('foobar');
22 |         assert(manager.hasClient('foobar'));
23 |         manager.removeClient('foobar');
24 |     });
25 | 
26 |     it('should create a new client with random id if previous exists', async () => {
27 |         const manager = new ClientManager();
28 |         const clientA = await manager.newClient('foobar');
29 |         const clientB = await manager.newClient('foobar');
30 |         assert(clientA.id, 'foobar');
31 |         assert(manager.hasClient(clientB.id));
32 |         assert(clientB.id != clientA.id);
33 |         manager.removeClient(clientB.id);
34 |         manager.removeClient('foobar');
35 |     });
36 | 
37 |     it('should remove client once it goes offline', async () => {
38 |         const manager = new ClientManager();
39 |         const client = await manager.newClient('foobar');
40 | 
41 |         const socket = await new Promise((resolve) => {
42 |             const netClient = net.createConnection({ port: client.port }, () => {
43 |                 resolve(netClient);
44 |             });
45 |         });
46 |         const closePromise = new Promise(resolve => socket.once('close', resolve));
47 |         socket.end();
48 |         await closePromise;
49 | 
50 |         // should still have client - grace period has not expired
51 |         assert(manager.hasClient('foobar'));
52 | 
53 |         // wait past grace period (1s)
54 |         await new Promise(resolve => setTimeout(resolve, 1500));
55 |         assert(!manager.hasClient('foobar'));
56 |     }).timeout(5000);
57 | 
58 |     it('should remove correct client once it goes offline', async () => {
59 |         const manager = new ClientManager();
60 |         const clientFoo = await manager.newClient('foo');
61 |         const clientBar = await manager.newClient('bar');
62 | 
63 |         const socket = await new Promise((resolve) => {
64 |             const netClient = net.createConnection({ port: clientFoo.port }, () => {
65 |                 resolve(netClient);
66 |             });
67 |         });
68 | 
69 |         await new Promise(resolve => setTimeout(resolve, 1500));
70 | 
71 |         // foo should still be ok
72 |         assert(manager.hasClient('foo'));
73 | 
74 |         // clientBar shound be removed - nothing connected to it
75 |         assert(!manager.hasClient('bar'));
76 | 
77 |         manager.removeClient('foo');
78 |         socket.end();
79 |     }).timeout(5000);
80 | 
81 |     it('should remove clients if they do not connect within 5 seconds', async () => {
82 |         const manager = new ClientManager();
83 |         const clientFoo = await manager.newClient('foo');
84 |         assert(manager.hasClient('foo'));
85 | 
86 |         // wait past grace period (1s)
87 |         await new Promise(resolve => setTimeout(resolve, 1500));
88 |         assert(!manager.hasClient('foo'));
89 |     }).timeout(5000);
90 | });
```

lib/TunnelAgent.js
```
1 | import { Agent } from 'http';
2 | import net from 'net';
3 | import assert from 'assert';
4 | import log from 'book';
5 | import Debug from 'debug';
6 | 
7 | const DEFAULT_MAX_SOCKETS = 10;
8 | 
9 | // Implements an http.Agent interface to a pool of tunnel sockets
10 | // A tunnel socket is a connection _from_ a client that will
11 | // service http requests. This agent is usable wherever one can use an http.Agent
12 | class TunnelAgent extends Agent {
13 |     constructor(options = {}) {
14 |         super({
15 |             keepAlive: true,
16 |             // only allow keepalive to hold on to one socket
17 |             // this prevents it from holding on to all the sockets so they can be used for upgrades
18 |             maxFreeSockets: 1,
19 |         });
20 | 
21 |         // sockets we can hand out via createConnection
22 |         this.availableSockets = [];
23 | 
24 |         // when a createConnection cannot return a socket, it goes into a queue
25 |         // once a socket is available it is handed out to the next callback
26 |         this.waitingCreateConn = [];
27 | 
28 |         this.debug = Debug(`lt:TunnelAgent[${options.clientId}]`);
29 | 
30 |         // track maximum allowed sockets
31 |         this.connectedSockets = 0;
32 |         this.maxTcpSockets = options.maxTcpSockets || DEFAULT_MAX_SOCKETS;
33 | 
34 |         // new tcp server to service requests for this client
35 |         this.server = net.createServer();
36 | 
37 |         // flag to avoid double starts
38 |         this.started = false;
39 |         this.closed = false;
40 |     }
41 | 
42 |     stats() {
43 |         return {
44 |             connectedSockets: this.connectedSockets,
45 |         };
46 |     }
47 | 
48 |     listen() {
49 |         const server = this.server;
50 |         if (this.started) {
51 |             throw new Error('already started');
52 |         }
53 |         this.started = true;
54 | 
55 |         server.on('close', this._onClose.bind(this));
56 |         server.on('connection', this._onConnection.bind(this));
57 |         server.on('error', (err) => {
58 |             // These errors happen from killed connections, we don't worry about them
59 |             if (err.code == 'ECONNRESET' || err.code == 'ETIMEDOUT') {
60 |                 return;
61 |             }
62 |             log.error(err);
63 |         });
64 | 
65 |         return new Promise((resolve) => {
66 |             server.listen(() => {
67 |                 const port = server.address().port;
68 |                 this.debug('tcp server listening on port: %d', port);
69 | 
70 |                 resolve({
71 |                     // port for lt client tcp connections
72 |                     port: port,
73 |                 });
74 |             });
75 |         });
76 |     }
77 | 
78 |     _onClose() {
79 |         this.closed = true;
80 |         this.debug('closed tcp socket');
81 |         // flush any waiting connections
82 |         for (const conn of this.waitingCreateConn) {
83 |             conn(new Error('closed'), null);
84 |         }
85 |         this.waitingCreateConn = [];
86 |         this.emit('end');
87 |     }
88 | 
89 |     // new socket connection from client for tunneling requests to client
90 |     _onConnection(socket) {
91 |         // no more socket connections allowed
92 |         if (this.connectedSockets >= this.maxTcpSockets) {
93 |             this.debug('no more sockets allowed');
94 |             socket.destroy();
95 |             return false;
96 |         }
97 | 
98 |         socket.once('close', (hadError) => {
99 |             this.debug('closed socket (error: %s)', hadError);
100 |             this.connectedSockets -= 1;
101 |             // remove the socket from available list
102 |             const idx = this.availableSockets.indexOf(socket);
103 |             if (idx >= 0) {
104 |                 this.availableSockets.splice(idx, 1);
105 |             }
106 | 
107 |             this.debug('connected sockets: %s', this.connectedSockets);
108 |             if (this.connectedSockets <= 0) {
109 |                 this.debug('all sockets disconnected');
110 |                 this.emit('offline');
111 |             }
112 |         });
113 | 
114 |         // close will be emitted after this
115 |         socket.once('error', (err) => {
116 |             // we do not log these errors, sessions can drop from clients for many reasons
117 |             // these are not actionable errors for our server
118 |             socket.destroy();
119 |         });
120 | 
121 |         if (this.connectedSockets === 0) {
122 |             this.emit('online');
123 |         }
124 | 
125 |         this.connectedSockets += 1;
126 |         this.debug('new connection from: %s:%s', socket.address().address, socket.address().port);
127 | 
128 |         // if there are queued callbacks, give this socket now and don't queue into available
129 |         const fn = this.waitingCreateConn.shift();
130 |         if (fn) {
131 |             this.debug('giving socket to queued conn request');
132 |             setTimeout(() => {
133 |                 fn(null, socket);
134 |             }, 0);
135 |             return;
136 |         }
137 | 
138 |         // make socket available for those waiting on sockets
139 |         this.availableSockets.push(socket);
140 |     }
141 | 
142 |     // fetch a socket from the available socket pool for the agent
143 |     // if no socket is available, queue
144 |     // cb(err, socket)
145 |     createConnection(options, cb) {
146 |         if (this.closed) {
147 |             cb(new Error('closed'));
148 |             return;
149 |         }
150 | 
151 |         this.debug('create connection');
152 | 
153 |         // socket is a tcp connection back to the user hosting the site
154 |         const sock = this.availableSockets.shift();
155 | 
156 |         // no available sockets
157 |         // wait until we have one
158 |         if (!sock) {
159 |             this.waitingCreateConn.push(cb);
160 |             this.debug('waiting connected: %s', this.connectedSockets);
161 |             this.debug('waiting available: %s', this.availableSockets.length);
162 |             return;
163 |         }
164 | 
165 |         this.debug('socket given');
166 |         cb(null, sock);
167 |     }
168 | 
169 |     destroy() {
170 |         this.server.close();
171 |         super.destroy();
172 |     }
173 | }
174 | 
175 | export default TunnelAgent;
```

lib/TunnelAgent.test.js
```
1 | import http from 'http';
2 | import net from 'net';
3 | import assert from 'assert';
4 | 
5 | import TunnelAgent from './TunnelAgent';
6 | 
7 | describe('TunnelAgent', () => {
8 |     it('should create an empty agent', async () => {
9 |         const agent = new TunnelAgent();
10 |         assert.equal(agent.started, false);
11 | 
12 |         const info = await agent.listen();
13 |         assert.ok(info.port > 0);
14 |         agent.destroy();
15 |     });
16 | 
17 |     it('should create a new server and accept connections', async () => {
18 |         const agent = new TunnelAgent();
19 |         assert.equal(agent.started, false);
20 | 
21 |         const info = await agent.listen();
22 |         const sock = net.createConnection({ port: info.port });
23 | 
24 |         // in this test we wait for the socket to be connected
25 |         await new Promise(resolve => sock.once('connect', resolve));
26 | 
27 |         const agentSock = await new Promise((resolve, reject) => {
28 |             agent.createConnection({}, (err, sock) => {
29 |                 if (err) {
30 |                     reject(err);
31 |                 }
32 |                 resolve(sock);
33 |             });
34 |         });
35 | 
36 |         agentSock.write('foo');
37 |         await new Promise(resolve => sock.once('readable', resolve));
38 | 
39 |         assert.equal('foo', sock.read().toString());
40 |         agent.destroy();
41 |         sock.destroy();
42 |     });
43 | 
44 |     it('should reject connections over the max', async () => {
45 |         const agent = new TunnelAgent({
46 |             maxTcpSockets: 2,
47 |         });
48 |         assert.equal(agent.started, false);
49 | 
50 |         const info = await agent.listen();
51 |         const sock1 = net.createConnection({ port: info.port });
52 |         const sock2 = net.createConnection({ port: info.port });
53 | 
54 |         // two valid socket connections
55 |         const p1 = new Promise(resolve => sock1.once('connect', resolve));
56 |         const p2 = new Promise(resolve => sock2.once('connect', resolve));
57 |         await Promise.all([p1, p2]);
58 | 
59 |         const sock3 = net.createConnection({ port: info.port });
60 |         const p3 = await new Promise(resolve => sock3.once('close', resolve));
61 | 
62 |         agent.destroy();
63 |         sock1.destroy();
64 |         sock2.destroy();
65 |         sock3.destroy();
66 |     });
67 | 
68 |     it('should queue createConnection requests', async () => {
69 |         const agent = new TunnelAgent();
70 |         assert.equal(agent.started, false);
71 | 
72 |         const info = await agent.listen();
73 | 
74 |         // create a promise for the next connection
75 |         let fulfilled = false;
76 |         const waitSockPromise = new Promise((resolve, reject) => {
77 |             agent.createConnection({}, (err, sock) => {
78 |                 fulfilled = true;
79 |                 if (err) {
80 |                     reject(err);
81 |                 }
82 |                 resolve(sock);
83 |             });
84 |         });
85 | 
86 |         // check that the next socket is not yet available
87 |         await new Promise(resolve => setTimeout(resolve, 500));
88 |         assert(!fulfilled);
89 | 
90 |         // connect, this will make a socket available
91 |         const sock = net.createConnection({ port: info.port });
92 |         await new Promise(resolve => sock.once('connect', resolve));
93 | 
94 |         const anotherAgentSock = await waitSockPromise;
95 |         agent.destroy();
96 |         sock.destroy();
97 |     });
98 | 
99 |     it('should should emit a online event when a socket connects', async () => {
100 |         const agent = new TunnelAgent();
101 |         const info = await agent.listen();
102 | 
103 |         const onlinePromise = new Promise(resolve => agent.once('online', resolve));
104 | 
105 |         const sock = net.createConnection({ port: info.port });
106 |         await new Promise(resolve => sock.once('connect', resolve));
107 | 
108 |         await onlinePromise;
109 |         agent.destroy();
110 |         sock.destroy();
111 |     });
112 | 
113 |     it('should emit offline event when socket disconnects', async () => {
114 |         const agent = new TunnelAgent();
115 |         const info = await agent.listen();
116 | 
117 |         const offlinePromise = new Promise(resolve => agent.once('offline', resolve));
118 | 
119 |         const sock = net.createConnection({ port: info.port });
120 |         await new Promise(resolve => sock.once('connect', resolve));
121 | 
122 |         sock.end();
123 |         await offlinePromise;
124 |         agent.destroy();
125 |         sock.destroy();
126 |     });
127 | 
128 |     it('should emit offline event only when last socket disconnects', async () => {
129 |         const agent = new TunnelAgent();
130 |         const info = await agent.listen();
131 | 
132 |         const offlinePromise = new Promise(resolve => agent.once('offline', resolve));
133 | 
134 |         const sockA = net.createConnection({ port: info.port });
135 |         await new Promise(resolve => sockA.once('connect', resolve));
136 |         const sockB = net.createConnection({ port: info.port });
137 |         await new Promise(resolve => sockB.once('connect', resolve));
138 | 
139 |         sockA.end();
140 | 
141 |         const timeout = new Promise(resolve => setTimeout(resolve, 500));
142 |         await Promise.race([offlinePromise, timeout]);
143 | 
144 |         sockB.end();
145 |         await offlinePromise;
146 | 
147 |         agent.destroy();
148 |     });
149 | 
150 |     it('should error an http request', async () => {
151 |         class ErrorAgent extends http.Agent {
152 |             constructor() {
153 |                 super();
154 |             }
155 |         
156 |             createConnection(options, cb) {
157 |                 cb(new Error('foo'));
158 |             }
159 |         }
160 | 
161 |         const agent = new ErrorAgent();
162 | 
163 |         const opt = {
164 |             host: 'localhost',
165 |             port: 1234,
166 |             path: '/',
167 |             agent: agent,
168 |         };
169 | 
170 |         const err = await new Promise((resolve) => {
171 |             const req = http.get(opt, (res) => {});
172 |             req.once('error', resolve);
173 |         });
174 |         assert.equal(err.message, 'foo');
175 |     });
176 | 
177 |     it('should return stats', async () => {
178 |         const agent = new TunnelAgent();
179 |         assert.deepEqual(agent.stats(), {
180 |             connectedSockets: 0,
181 |         });
182 |     });
183 | });
```
