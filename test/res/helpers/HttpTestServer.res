type route = {
  path: string,
  status: int,
  location: option<string>,
  body: string,
  contentType?: string,
  rawBody?: array<int>,
}

type t

let start: array<route> => promise<
  t,
> = %raw(`routes => import('node:http').then(({ createServer }) => new Promise((resolve, reject) => {
  const requests = [];
  const server = createServer((req, res) => {
    requests.push({ path: req.url, headers: req.headers });
    const route = routes.find(candidate => candidate.path === req.url);
    if (!route) {
      res.statusCode = 404;
      res.end('Not found');
      return;
    }
    res.statusCode = route.status;
    if (route.location !== undefined) {
      res.setHeader('Location', route.location.replaceAll('%PORT%', String(server.address().port)));
    }
    res.setHeader('Content-Type', route.contentType ?? 'text/html');
    res.end(route.rawBody === undefined ? route.body : Buffer.from(route.rawBody));
  });
  server.once('error', reject);
  server.listen(0, '127.0.0.1', () => {
    resolve({
      port: server.address().port,
      requests,
      close: () => new Promise((resolveClose, rejectClose) =>
        server.close(error => error ? rejectClose(error) : resolveClose())
      ),
    });
  });
}))`)

@get external port: t => int = "port"
@send external close: t => promise<unit> = "close"
let recordedHeader: (t, string, string) => option<string> = %raw(`(server, path, name) => {
  const request = server.requests.find(item => item.path === path);
  if (!request) return undefined;
  const value = request.headers[name.toLowerCase()];
  return value === undefined ? undefined : value;
}`)
