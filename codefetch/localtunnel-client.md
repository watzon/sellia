localtunnel.js
```
1 | const Tunnel = require('./lib/Tunnel');
2 | 
3 | module.exports = function localtunnel(arg1, arg2, arg3) {
4 |   const options = typeof arg1 === 'object' ? arg1 : { ...arg2, port: arg1 };
5 |   const callback = typeof arg1 === 'object' ? arg2 : arg3;
6 |   const client = new Tunnel(options);
7 |   if (callback) {
8 |     client.open(err => (err ? callback(err) : callback(null, client)));
9 |     return client;
10 |   }
11 |   return new Promise((resolve, reject) =>
12 |     client.open(err => (err ? reject(err) : resolve(client)))
13 |   );
14 | };
```

localtunnel.spec.js
```
1 | /* eslint-disable no-console */
2 | 
3 | const crypto = require('crypto');
4 | const http = require('http');
5 | const https = require('https');
6 | const url = require('url');
7 | const assert = require('assert');
8 | 
9 | const localtunnel = require('./localtunnel');
10 | 
11 | let fakePort;
12 | 
13 | before(done => {
14 |   const server = http.createServer();
15 |   server.on('request', (req, res) => {
16 |     res.write(req.headers.host);
17 |     res.end();
18 |   });
19 |   server.listen(() => {
20 |     const { port } = server.address();
21 |     fakePort = port;
22 |     done();
23 |   });
24 | });
25 | 
26 | it('query localtunnel server w/ ident', async done => {
27 |   const tunnel = await localtunnel({ port: fakePort });
28 |   assert.ok(new RegExp('^https://.*localtunnel.me$').test(tunnel.url));
29 | 
30 |   const parsed = url.parse(tunnel.url);
31 |   const opt = {
32 |     host: parsed.host,
33 |     port: 443,
34 |     headers: { host: parsed.hostname },
35 |     path: '/',
36 |   };
37 | 
38 |   const req = https.request(opt, res => {
39 |     res.setEncoding('utf8');
40 |     let body = '';
41 | 
42 |     res.on('data', chunk => {
43 |       body += chunk;
44 |     });
45 | 
46 |     res.on('end', () => {
47 |       assert(/.*[.]localtunnel[.]me/.test(body), body);
48 |       tunnel.close();
49 |       done();
50 |     });
51 |   });
52 | 
53 |   req.end();
54 | });
55 | 
56 | it('request specific domain', async () => {
57 |   const subdomain = Math.random()
58 |     .toString(36)
59 |     .substr(2);
60 |   const tunnel = await localtunnel({ port: fakePort, subdomain });
61 |   assert.ok(new RegExp(`^https://${subdomain}.localtunnel.me$`).test(tunnel.url));
62 |   tunnel.close();
63 | });
64 | 
65 | describe('--local-host localhost', () => {
66 |   it('override Host header with local-host', async done => {
67 |     const tunnel = await localtunnel({ port: fakePort, local_host: 'localhost' });
68 |     assert.ok(new RegExp('^https://.*localtunnel.me$').test(tunnel.url));
69 | 
70 |     const parsed = url.parse(tunnel.url);
71 |     const opt = {
72 |       host: parsed.host,
73 |       port: 443,
74 |       headers: { host: parsed.hostname },
75 |       path: '/',
76 |     };
77 | 
78 |     const req = https.request(opt, res => {
79 |       res.setEncoding('utf8');
80 |       let body = '';
81 | 
82 |       res.on('data', chunk => {
83 |         body += chunk;
84 |       });
85 | 
86 |       res.on('end', () => {
87 |         assert.strictEqual(body, 'localhost');
88 |         tunnel.close();
89 |         done();
90 |       });
91 |     });
92 | 
93 |     req.end();
94 |   });
95 | });
96 | 
97 | describe('--local-host 127.0.0.1', () => {
98 |   it('override Host header with local-host', async done => {
99 |     const tunnel = await localtunnel({ port: fakePort, local_host: '127.0.0.1' });
100 |     assert.ok(new RegExp('^https://.*localtunnel.me$').test(tunnel.url));
101 | 
102 |     const parsed = url.parse(tunnel.url);
103 |     const opt = {
104 |       host: parsed.host,
105 |       port: 443,
106 |       headers: {
107 |         host: parsed.hostname,
108 |       },
109 |       path: '/',
110 |     };
111 | 
112 |     const req = https.request(opt, res => {
113 |       res.setEncoding('utf8');
114 |       let body = '';
115 | 
116 |       res.on('data', chunk => {
117 |         body += chunk;
118 |       });
119 | 
120 |       res.on('end', () => {
121 |         assert.strictEqual(body, '127.0.0.1');
122 |         tunnel.close();
123 |         done();
124 |       });
125 |     });
126 | 
127 |     req.end();
128 |   });
129 | 
130 |   it('send chunked request', async done => {
131 |     const tunnel = await localtunnel({ port: fakePort, local_host: '127.0.0.1' });
132 |     assert.ok(new RegExp('^https://.*localtunnel.me$').test(tunnel.url));
133 | 
134 |     const parsed = url.parse(tunnel.url);
135 |     const opt = {
136 |       host: parsed.host,
137 |       port: 443,
138 |       headers: {
139 |         host: parsed.hostname,
140 |         'Transfer-Encoding': 'chunked',
141 |       },
142 |       path: '/',
143 |     };
144 | 
145 |     const req = https.request(opt, res => {
146 |       res.setEncoding('utf8');
147 |       let body = '';
148 | 
149 |       res.on('data', chunk => {
150 |         body += chunk;
151 |       });
152 | 
153 |       res.on('end', () => {
154 |         assert.strictEqual(body, '127.0.0.1');
155 |         tunnel.close();
156 |         done();
157 |       });
158 |     });
159 | 
160 |     req.end(crypto.randomBytes(1024 * 8).toString('base64'));
161 |   });
162 | });
```

bin/lt.js
```
1 | #!/usr/bin/env node
2 | /* eslint-disable no-console */
3 | 
4 | const openurl = require('openurl');
5 | const yargs = require('yargs');
6 | 
7 | const localtunnel = require('../localtunnel');
8 | const { version } = require('../package');
9 | 
10 | const { argv } = yargs
11 |   .usage('Usage: lt --port [num] <options>')
12 |   .env(true)
13 |   .option('p', {
14 |     alias: 'port',
15 |     describe: 'Internal HTTP server port',
16 |   })
17 |   .option('h', {
18 |     alias: 'host',
19 |     describe: 'Upstream server providing forwarding',
20 |     default: 'https://localtunnel.me',
21 |   })
22 |   .option('s', {
23 |     alias: 'subdomain',
24 |     describe: 'Request this subdomain',
25 |   })
26 |   .option('l', {
27 |     alias: 'local-host',
28 |     describe: 'Tunnel traffic to this host instead of localhost, override Host header to this host',
29 |   })
30 |   .option('local-https', {
31 |     describe: 'Tunnel traffic to a local HTTPS server',
32 |   })
33 |   .option('local-cert', {
34 |     describe: 'Path to certificate PEM file for local HTTPS server',
35 |   })
36 |   .option('local-key', {
37 |     describe: 'Path to certificate key file for local HTTPS server',
38 |   })
39 |   .option('local-ca', {
40 |     describe: 'Path to certificate authority file for self-signed certificates',
41 |   })
42 |   .option('allow-invalid-cert', {
43 |     describe: 'Disable certificate checks for your local HTTPS server (ignore cert/key/ca options)',
44 |   })
45 |   .options('o', {
46 |     alias: 'open',
47 |     describe: 'Opens the tunnel URL in your browser',
48 |   })
49 |   .option('print-requests', {
50 |     describe: 'Print basic request info',
51 |   })
52 |   .require('port')
53 |   .boolean('local-https')
54 |   .boolean('allow-invalid-cert')
55 |   .boolean('print-requests')
56 |   .help('help', 'Show this help and exit')
57 |   .version(version);
58 | 
59 | if (typeof argv.port !== 'number') {
60 |   yargs.showHelp();
61 |   console.error('\nInvalid argument: `port` must be a number');
62 |   process.exit(1);
63 | }
64 | 
65 | (async () => {
66 |   const tunnel = await localtunnel({
67 |     port: argv.port,
68 |     host: argv.host,
69 |     subdomain: argv.subdomain,
70 |     local_host: argv.localHost,
71 |     local_https: argv.localHttps,
72 |     local_cert: argv.localCert,
73 |     local_key: argv.localKey,
74 |     local_ca: argv.localCa,
75 |     allow_invalid_cert: argv.allowInvalidCert,
76 |   }).catch(err => {
77 |     throw err;
78 |   });
79 | 
80 |   tunnel.on('error', err => {
81 |     throw err;
82 |   });
83 | 
84 |   console.log('your url is: %s', tunnel.url);
85 | 
86 |   /**
87 |    * `cachedUrl` is set when using a proxy server that support resource caching.
88 |    * This URL generally remains available after the tunnel itself has closed.
89 |    * @see https://github.com/localtunnel/localtunnel/pull/319#discussion_r319846289
90 |    */
91 |   if (tunnel.cachedUrl) {
92 |     console.log('your cachedUrl is: %s', tunnel.cachedUrl);
93 |   }
94 | 
95 |   if (argv.open) {
96 |     openurl.open(tunnel.url);
97 |   }
98 | 
99 |   if (argv['print-requests']) {
100 |     tunnel.on('request', info => {
101 |       console.log(new Date().toString(), info.method, info.path);
102 |     });
103 |   }
104 | })();
```

lib/HeaderHostTransformer.js
```
1 | const { Transform } = require('stream');
2 | 
3 | class HeaderHostTransformer extends Transform {
4 |   constructor(opts = {}) {
5 |     super(opts);
6 |     this.host = opts.host || 'localhost';
7 |     this.replaced = false;
8 |   }
9 | 
10 |   _transform(data, encoding, callback) {
11 |     callback(
12 |       null,
13 |       this.replaced // after replacing the first instance of the Host header we just become a regular passthrough
14 |         ? data
15 |         : data.toString().replace(/(\r\n[Hh]ost: )\S+/, (match, $1) => {
16 |             this.replaced = true;
17 |             return $1 + this.host;
18 |           })
19 |     );
20 |   }
21 | }
22 | 
23 | module.exports = HeaderHostTransformer;
```

lib/Tunnel.js
```
1 | /* eslint-disable consistent-return, no-underscore-dangle */
2 | 
3 | const { parse } = require('url');
4 | const { EventEmitter } = require('events');
5 | const axios = require('axios');
6 | const debug = require('debug')('localtunnel:client');
7 | 
8 | const TunnelCluster = require('./TunnelCluster');
9 | 
10 | module.exports = class Tunnel extends EventEmitter {
11 |   constructor(opts = {}) {
12 |     super(opts);
13 |     this.opts = opts;
14 |     this.closed = false;
15 |     if (!this.opts.host) {
16 |       this.opts.host = 'https://localtunnel.me';
17 |     }
18 |   }
19 | 
20 |   _getInfo(body) {
21 |     /* eslint-disable camelcase */
22 |     const { id, ip, port, url, cached_url, max_conn_count } = body;
23 |     const { host, port: local_port, local_host } = this.opts;
24 |     const { local_https, local_cert, local_key, local_ca, allow_invalid_cert } = this.opts;
25 |     return {
26 |       name: id,
27 |       url,
28 |       cached_url,
29 |       max_conn: max_conn_count || 1,
30 |       remote_host: parse(host).hostname,
31 |       remote_ip: ip,
32 |       remote_port: port,
33 |       local_port,
34 |       local_host,
35 |       local_https,
36 |       local_cert,
37 |       local_key,
38 |       local_ca,
39 |       allow_invalid_cert,
40 |     };
41 |     /* eslint-enable camelcase */
42 |   }
43 | 
44 |   // initialize connection
45 |   // callback with connection info
46 |   _init(cb) {
47 |     const opt = this.opts;
48 |     const getInfo = this._getInfo.bind(this);
49 | 
50 |     const params = {
51 |       responseType: 'json',
52 |     };
53 | 
54 |     const baseUri = `${opt.host}/`;
55 |     // no subdomain at first, maybe use requested domain
56 |     const assignedDomain = opt.subdomain;
57 |     // where to quest
58 |     const uri = baseUri + (assignedDomain || '?new');
59 | 
60 |     (function getUrl() {
61 |       axios
62 |         .get(uri, params)
63 |         .then(res => {
64 |           const body = res.data;
65 |           debug('got tunnel information', res.data);
66 |           if (res.status !== 200) {
67 |             const err = new Error(
68 |               (body && body.message) || 'localtunnel server returned an error, please try again'
69 |             );
70 |             return cb(err);
71 |           }
72 |           cb(null, getInfo(body));
73 |         })
74 |         .catch(err => {
75 |           debug(`tunnel server offline: ${err.message}, retry 1s`);
76 |           return setTimeout(getUrl, 1000);
77 |         });
78 |     })();
79 |   }
80 | 
81 |   _establish(info) {
82 |     // increase max event listeners so that localtunnel consumers don't get
83 |     // warning messages as soon as they setup even one listener. See #71
84 |     this.setMaxListeners(info.max_conn + (EventEmitter.defaultMaxListeners || 10));
85 | 
86 |     this.tunnelCluster = new TunnelCluster(info);
87 | 
88 |     // only emit the url the first time
89 |     this.tunnelCluster.once('open', () => {
90 |       this.emit('url', info.url);
91 |     });
92 | 
93 |     // re-emit socket error
94 |     this.tunnelCluster.on('error', err => {
95 |       debug('got socket error', err.message);
96 |       this.emit('error', err);
97 |     });
98 | 
99 |     let tunnelCount = 0;
100 | 
101 |     // track open count
102 |     this.tunnelCluster.on('open', tunnel => {
103 |       tunnelCount++;
104 |       debug('tunnel open [total: %d]', tunnelCount);
105 | 
106 |       const closeHandler = () => {
107 |         tunnel.destroy();
108 |       };
109 | 
110 |       if (this.closed) {
111 |         return closeHandler();
112 |       }
113 | 
114 |       this.once('close', closeHandler);
115 |       tunnel.once('close', () => {
116 |         this.removeListener('close', closeHandler);
117 |       });
118 |     });
119 | 
120 |     // when a tunnel dies, open a new one
121 |     this.tunnelCluster.on('dead', () => {
122 |       tunnelCount--;
123 |       debug('tunnel dead [total: %d]', tunnelCount);
124 |       if (this.closed) {
125 |         return;
126 |       }
127 |       this.tunnelCluster.open();
128 |     });
129 | 
130 |     this.tunnelCluster.on('request', req => {
131 |       this.emit('request', req);
132 |     });
133 | 
134 |     // establish as many tunnels as allowed
135 |     for (let count = 0; count < info.max_conn; ++count) {
136 |       this.tunnelCluster.open();
137 |     }
138 |   }
139 | 
140 |   open(cb) {
141 |     this._init((err, info) => {
142 |       if (err) {
143 |         return cb(err);
144 |       }
145 | 
146 |       this.clientId = info.name;
147 |       this.url = info.url;
148 | 
149 |       // `cached_url` is only returned by proxy servers that support resource caching.
150 |       if (info.cached_url) {
151 |         this.cachedUrl = info.cached_url;
152 |       }
153 | 
154 |       this._establish(info);
155 |       cb();
156 |     });
157 |   }
158 | 
159 |   close() {
160 |     this.closed = true;
161 |     this.emit('close');
162 |   }
163 | };
```

lib/TunnelCluster.js
```
1 | const { EventEmitter } = require('events');
2 | const debug = require('debug')('localtunnel:client');
3 | const fs = require('fs');
4 | const net = require('net');
5 | const tls = require('tls');
6 | 
7 | const HeaderHostTransformer = require('./HeaderHostTransformer');
8 | 
9 | // manages groups of tunnels
10 | module.exports = class TunnelCluster extends EventEmitter {
11 |   constructor(opts = {}) {
12 |     super(opts);
13 |     this.opts = opts;
14 |   }
15 | 
16 |   open() {
17 |     const opt = this.opts;
18 | 
19 |     // Prefer IP if returned by the server
20 |     const remoteHostOrIp = opt.remote_ip || opt.remote_host;
21 |     const remotePort = opt.remote_port;
22 |     const localHost = opt.local_host || 'localhost';
23 |     const localPort = opt.local_port;
24 |     const localProtocol = opt.local_https ? 'https' : 'http';
25 |     const allowInvalidCert = opt.allow_invalid_cert;
26 | 
27 |     debug(
28 |       'establishing tunnel %s://%s:%s <> %s:%s',
29 |       localProtocol,
30 |       localHost,
31 |       localPort,
32 |       remoteHostOrIp,
33 |       remotePort
34 |     );
35 | 
36 |     // connection to localtunnel server
37 |     const remote = net.connect({
38 |       host: remoteHostOrIp,
39 |       port: remotePort,
40 |     });
41 | 
42 |     remote.setKeepAlive(true);
43 | 
44 |     remote.on('error', err => {
45 |       debug('got remote connection error', err.message);
46 | 
47 |       // emit connection refused errors immediately, because they
48 |       // indicate that the tunnel can't be established.
49 |       if (err.code === 'ECONNREFUSED') {
50 |         this.emit(
51 |           'error',
52 |           new Error(
53 |             `connection refused: ${remoteHostOrIp}:${remotePort} (check your firewall settings)`
54 |           )
55 |         );
56 |       }
57 | 
58 |       remote.end();
59 |     });
60 | 
61 |     const connLocal = () => {
62 |       if (remote.destroyed) {
63 |         debug('remote destroyed');
64 |         this.emit('dead');
65 |         return;
66 |       }
67 | 
68 |       debug('connecting locally to %s://%s:%d', localProtocol, localHost, localPort);
69 |       remote.pause();
70 | 
71 |       if (allowInvalidCert) {
72 |         debug('allowing invalid certificates');
73 |       }
74 | 
75 |       const getLocalCertOpts = () =>
76 |         allowInvalidCert
77 |           ? { rejectUnauthorized: false }
78 |           : {
79 |               cert: fs.readFileSync(opt.local_cert),
80 |               key: fs.readFileSync(opt.local_key),
81 |               ca: opt.local_ca ? [fs.readFileSync(opt.local_ca)] : undefined,
82 |             };
83 | 
84 |       // connection to local http server
85 |       const local = opt.local_https
86 |         ? tls.connect({ host: localHost, port: localPort, ...getLocalCertOpts() })
87 |         : net.connect({ host: localHost, port: localPort });
88 | 
89 |       const remoteClose = () => {
90 |         debug('remote close');
91 |         this.emit('dead');
92 |         local.end();
93 |       };
94 | 
95 |       remote.once('close', remoteClose);
96 | 
97 |       // TODO some languages have single threaded servers which makes opening up
98 |       // multiple local connections impossible. We need a smarter way to scale
99 |       // and adjust for such instances to avoid beating on the door of the server
100 |       local.once('error', err => {
101 |         debug('local error %s', err.message);
102 |         local.end();
103 | 
104 |         remote.removeListener('close', remoteClose);
105 | 
106 |         if (err.code !== 'ECONNREFUSED'
107 |             && err.code !== 'ECONNRESET') {
108 |           return remote.end();
109 |         }
110 | 
111 |         // retrying connection to local server
112 |         setTimeout(connLocal, 1000);
113 |       });
114 | 
115 |       local.once('connect', () => {
116 |         debug('connected locally');
117 |         remote.resume();
118 | 
119 |         let stream = remote;
120 | 
121 |         // if user requested specific local host
122 |         // then we use host header transform to replace the host header
123 |         if (opt.local_host) {
124 |           debug('transform Host header to %s', opt.local_host);
125 |           stream = remote.pipe(new HeaderHostTransformer({ host: opt.local_host }));
126 |         }
127 | 
128 |         stream.pipe(local).pipe(remote);
129 | 
130 |         // when local closes, also get a new remote
131 |         local.once('close', hadError => {
132 |           debug('local connection closed [%s]', hadError);
133 |         });
134 |       });
135 |     };
136 | 
137 |     remote.on('data', data => {
138 |       const match = data.toString().match(/^(\w+) (\S+)/);
139 |       if (match) {
140 |         this.emit('request', {
141 |           method: match[1],
142 |           path: match[2],
143 |         });
144 |       }
145 |     });
146 | 
147 |     // tunnel is considered open when remote connects
148 |     remote.once('connect', () => {
149 |       this.emit('open', remote);
150 |       connLocal();
151 |     });
152 |   }
153 | };
```
