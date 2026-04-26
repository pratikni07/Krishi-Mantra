const https = require('https');
const http = require('http');

/**
 * Vertex uses `systemInstruction` separately from `contents`, and roles are
 * `user` | `model`. OpenAI uses `system` | `user` | `assistant` embedded in the
 * messages array. These adapters bridge both directions.
 */

function extractSystemInstruction(messages = []) {
  const systems = messages.filter((m) => m?.role === 'system' && m?.content);
  if (!systems.length) return undefined;
  const text = systems
    .map((m) => (typeof m.content === 'string' ? m.content : stringifyParts(m.content)))
    .join('\n\n');
  return text ? { parts: [{ text }] } : undefined;
}

function stringifyParts(parts) {
  if (!Array.isArray(parts)) return '';
  return parts
    .filter((p) => p?.type === 'text' && p.text)
    .map((p) => p.text)
    .join('\n');
}

function mapRole(role) {
  if (role === 'assistant') return 'model';
  if (role === 'system') return null;
  return 'user';
}

function isPresignedUrl(url) {
  if (!url) return false;
  return /[?&](X-Amz-Signature|X-Goog-Signature|Signature=)/i.test(url);
}

function guessMime(url) {
  const lower = String(url).split('?')[0].toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

function fetchBuffer(url, { timeoutMs = 15_000, maxBytes = 12 * 1024 * 1024 } = {}) {
  return new Promise((resolve, reject) => {
    const lib = url.startsWith('https:') ? https : http;
    const req = lib.get(url, (res) => {
      if (res.statusCode && res.statusCode >= 400) {
        res.resume();
        return reject(new Error(`image fetch failed: ${res.statusCode}`));
      }
      const chunks = [];
      let total = 0;
      res.on('data', (c) => {
        total += c.length;
        if (total > maxBytes) {
          req.destroy(new Error('image exceeds maxBytes'));
          return;
        }
        chunks.push(c);
      });
      res.on('end', () =>
        resolve({
          buffer: Buffer.concat(chunks),
          contentType: res.headers['content-type'] || guessMime(url),
        })
      );
      res.on('error', reject);
    });
    req.on('error', reject);
    req.setTimeout(timeoutMs, () => req.destroy(new Error('image fetch timeout')));
  });
}

function parseDataUrl(url) {
  // data:image/jpeg;base64,<...>
  const m = /^data:([^;]+);base64,(.+)$/.exec(url);
  if (!m) return null;
  return { mimeType: m[1], data: m[2] };
}

async function urlToInlinePart(url) {
  const dataUrl = parseDataUrl(url);
  if (dataUrl) {
    return {
      inlineData: { mimeType: dataUrl.mimeType, data: dataUrl.data },
    };
  }
  const { buffer, contentType } = await fetchBuffer(url);
  return {
    inlineData: { mimeType: contentType, data: buffer.toString('base64') },
  };
}

function urlToFileDataPart(url) {
  return { fileData: { fileUri: url, mimeType: guessMime(url) } };
}

/**
 * Convert OpenAI-style messages into Vertex `contents`. System messages are
 * stripped (consumed by extractSystemInstruction). Images inline-base64 when
 * presigned, fileData otherwise (Vertex can fetch public URLs).
 */
async function toVertexContents(messages = []) {
  const out = [];
  for (const m of messages) {
    const role = mapRole(m.role);
    if (!role) continue;
    if (typeof m.content === 'string') {
      out.push({ role, parts: [{ text: m.content }] });
      continue;
    }
    if (!Array.isArray(m.content)) continue;
    const parts = [];
    for (const p of m.content) {
      if (p?.type === 'text' && p.text) {
        parts.push({ text: p.text });
      } else if (p?.type === 'image_url') {
        const url = p.image_url?.url;
        if (!url) continue;
        if (parseDataUrl(url) || isPresignedUrl(url)) {
          parts.push(await urlToInlinePart(url));
        } else {
          parts.push(urlToFileDataPart(url));
        }
      }
    }
    if (parts.length) out.push({ role, parts });
  }
  return out;
}

/**
 * Extract a plain text response from a Vertex generateContent() result.
 */
function extractText(response) {
  const candidates = response?.response?.candidates || response?.candidates || [];
  const chunks = [];
  for (const c of candidates) {
    const parts = c?.content?.parts || [];
    for (const p of parts) if (p.text) chunks.push(p.text);
  }
  return chunks.join('');
}

/**
 * Normalize a Vertex generateContent usage field to our OpenAI-shaped metrics.
 */
function normalizeUsage(response) {
  const meta = response?.response?.usageMetadata || response?.usageMetadata;
  if (!meta) return {};
  return {
    prompt_tokens: meta.promptTokenCount ?? 0,
    completion_tokens: meta.candidatesTokenCount ?? 0,
    total_tokens: meta.totalTokenCount ?? 0,
    prompt_tokens_details: meta.cachedContentTokenCount
      ? { cached_tokens: meta.cachedContentTokenCount }
      : undefined,
  };
}

/**
 * Normalize a Vertex streaming response into our provider interface's
 * async iterable of { type: "delta"|"done"|"error", ... } events.
 */
async function* normalizeStream(vertexStream) {
  let usage = null;
  try {
    const iterable = vertexStream?.stream || vertexStream;
    for await (const chunk of iterable) {
      const parts = chunk?.candidates?.[0]?.content?.parts || [];
      for (const p of parts) {
        if (p.text) yield { type: 'delta', text: p.text };
      }
      if (chunk?.usageMetadata) usage = normalizeUsage({ usageMetadata: chunk.usageMetadata });
    }
    if (!usage && typeof vertexStream?.response === 'function') {
      try {
        const final = await vertexStream.response;
        usage = normalizeUsage({ response: final });
      } catch (err) {
        // ignore
      }
    }
    yield { type: 'done', usage: usage || {} };
  } catch (err) {
    yield { type: 'error', code: err?.code || 'stream_error', message: err.message };
  }
}

module.exports = {
  extractSystemInstruction,
  toVertexContents,
  extractText,
  normalizeUsage,
  normalizeStream,
  mapRole,
  isPresignedUrl,
  _test: { parseDataUrl, urlToInlinePart, urlToFileDataPart },
};
