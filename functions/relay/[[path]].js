// Cloudflare Pages Function for dentrascan.site/relay/*. deploy.sh publishes
// it with the web app (wrangler picks up this functions/ folder).
//
// The Dentra Cam reaches the DENTRA API through here rather than straight
// at Heroku. Its network stack keeps only about 5.7 KB in flight, so its
// upload speed is that divided by the round trip: Cloudflare's nearest
// server answers in milliseconds, Heroku's US servers in about 250 ms from
// the Philippines. Cloudflare carries it the rest of the way at full speed.
//
// WebSockets pass straight through. Only these paths are forwarded; the
// API checks every request itself (camera token, or a sign-in message).

const API = 'https://dentra-api-418c4814cfb7.herokuapp.com';

const ROUTES = {
  // The camera: linking with a pairing code, and its live link.
  '/relay/claim': '/api/cam/device/claim',
  '/relay/ws': '/api/cam/device/ws',
  // A browser watching a camera.
  '/relay/viewer': '/api/cam/ws',
};

export async function onRequest({ request }) {
  const path = ROUTES[new URL(request.url).pathname];
  if (!path) return new Response('Not found', { status: 404 });

  // A WebSocket: hand the whole request on, and the socket passes through.
  if (request.headers.get('Upgrade')?.toLowerCase() === 'websocket') {
    return fetch(new Request(API + path, request));
  }

  // Anything else is a small JSON call. Read the body first and let fetch
  // set its length: passing the camera's stream on with its original
  // Content-Length left the API waiting for a body that never finished.
  const headers = new Headers(request.headers);
  headers.delete('content-length');
  headers.delete('host');
  const hasBody = request.method !== 'GET' && request.method !== 'HEAD';
  return fetch(API + path, {
    method: request.method,
    headers,
    body: hasBody ? await request.arrayBuffer() : undefined,
  });
}
