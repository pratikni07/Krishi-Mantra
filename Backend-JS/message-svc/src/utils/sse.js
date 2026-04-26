function open(res) {
  res.status(200);
  res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
  res.setHeader('Cache-Control', 'no-cache, no-transform');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');
  if (typeof res.flushHeaders === 'function') res.flushHeaders();
}

function data(res, payload) {
  if (res.writableEnded) return;
  res.write(`data: ${JSON.stringify(payload)}\n\n`);
}

function keepalive(res) {
  if (res.writableEnded) return;
  res.write(': ping\n\n');
}

function close(res) {
  if (res.writableEnded) return;
  res.end();
}

module.exports = { open, data, keepalive, close };
