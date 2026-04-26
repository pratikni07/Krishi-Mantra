let VertexAI;
try {
  ({ VertexAI } = require('@google-cloud/vertexai'));
} catch (err) {
  VertexAI = null;
}

const logger = require('../utils/logger');
const { costFor } = require('../utils/cost-table');
const redis = require('../config/redis');
const adapters = require('./vertex-adapters');

const CTX_CACHE_KEY = (fp) => `vertex:ctx-cache:${fp}`;
const CTX_CACHE_TTL_SECONDS = 60 * 60;
const CTX_CACHE_MIN_TOKENS = 4096;

const RETRY_CODES = new Set([4, 8, 13, 14]);

function approxTokenCount(text) {
  if (!text) return 0;
  return Math.ceil(String(text).length / 4);
}

function countMessageTokens(messages) {
  let total = 0;
  for (const m of messages || []) {
    total += 4;
    if (typeof m.content === 'string') total += approxTokenCount(m.content);
    else if (Array.isArray(m.content)) {
      for (const part of m.content) {
        if (part?.type === 'text' && part.text) total += approxTokenCount(part.text);
        else if (part?.type === 'image_url') total += 258;
      }
    }
  }
  return total + 2;
}

function bind(cfg) {
  if (!VertexAI) {
    throw new Error(
      '@google-cloud/vertexai not installed. Run `npm install @google-cloud/vertexai google-auth-library` in message-svc.'
    );
  }

  const extras = cfg.extras || {};
  const regions = Array.isArray(extras.regions) && extras.regions.length
    ? extras.regions
    : [extras.location || 'asia-south1'];

  const cred = cfg.credentials || {};
  let googleAuthOptions = {};
  let project;

  if (cred.type === 'service_account_json') {
    const sa = cred.serviceAccount || {};
    project = extras.project || sa.project_id;
    if (!project) {
      throw new Error('Vertex config missing extras.project (and service account has no project_id)');
    }
    googleAuthOptions = {
      credentials: {
        client_email: sa.client_email,
        private_key: sa.private_key,
      },
      projectId: project,
    };
  } else if (cred.type === 'wif') {
    project = extras.project;
    if (!project) throw new Error('Vertex WIF config requires extras.project');
    googleAuthOptions = extras.workloadIdentity || {};
  } else {
    throw new Error(`Unsupported vertex credential type: ${cred.type}`);
  }

  const clientCache = new Map();
  const clientFor = (location) => {
    const key = `${project}|${location}`;
    if (clientCache.has(key)) return clientCache.get(key);
    const inst = new VertexAI({ project, location, googleAuthOptions });
    clientCache.set(key, inst);
    return inst;
  };

  async function withRetry(fn, { max = 4 } = {}) {
    let lastErr;
    let regionIndex = 0;
    for (let attempt = 0; attempt < max; attempt++) {
      const location = regions[regionIndex % regions.length];
      try {
        return await fn(clientFor(location), location);
      } catch (err) {
        lastErr = err;
        const code = err?.code;
        if (code === 16 || /UNAUTHENTICATED/i.test(err.message || '')) throw err;
        if (!RETRY_CODES.has(code) && !/UNAVAILABLE|RESOURCE_EXHAUSTED|DEADLINE/i.test(err.message || '')) {
          throw err;
        }
        if (code === 8 && regions.length > 1) regionIndex += 1;
        const backoff = Math.min(10_000, 2 ** attempt * 500 + Math.random() * 250);
        logger.warn('vertex retry', { attempt: attempt + 1, code, backoff, location });
        await new Promise((r) => setTimeout(r, backoff));
      }
    }
    throw lastErr;
  }

  async function maybeEnsureContextCache({ systemInstruction, contents, model, fingerprint, prefixTokens }) {
    if (!fingerprint || prefixTokens < CTX_CACHE_MIN_TOKENS) return null;
    const key = CTX_CACHE_KEY(fingerprint);
    try {
      const existing = await redis.get(key);
      if (existing) return existing;
    } catch (err) {
      // fall through
    }
    try {
      const client = clientFor(regions[0]);
      if (typeof client.cachedContents?.create !== 'function') return null;
      const created = await client.cachedContents.create({
        model,
        systemInstruction,
        contents,
        ttl: `${CTX_CACHE_TTL_SECONDS}s`,
      });
      const name = created?.name;
      if (name) {
        await redis.setex(key, CTX_CACHE_TTL_SECONDS, name);
        return name;
      }
    } catch (err) {
      logger.warn('vertex context-cache create failed', { error: err.message });
    }
    return null;
  }

  async function streamChat({
    messages,
    model = cfg.models?.chat || 'gemini-2.5-flash',
    userId,
    maxTokens = 800,
    temperature = 0.4,
    fingerprint,
    prefixTokens = 0,
  }) {
    const systemInstruction = adapters.extractSystemInstruction(messages);
    const contents = await adapters.toVertexContents(messages);

    const cachedContent = await maybeEnsureContextCache({
      systemInstruction,
      contents,
      model,
      fingerprint,
      prefixTokens,
    });

    const vertexStream = await withRetry(async (client) => {
      const generative = client.getGenerativeModel({
        model,
        systemInstruction,
        generationConfig: { maxOutputTokens: maxTokens, temperature },
      });
      const req = { contents };
      if (cachedContent) req.cachedContent = cachedContent;
      return generative.generateContentStream(req);
    });

    return adapters.normalizeStream(vertexStream);
  }

  async function chat({
    messages,
    model = cfg.models?.chat || 'gemini-2.5-flash',
    userId,
    maxTokens = 400,
    temperature = 0.3,
    fingerprint,
    prefixTokens = 0,
  }) {
    const systemInstruction = adapters.extractSystemInstruction(messages);
    const contents = await adapters.toVertexContents(messages);
    const cachedContent = await maybeEnsureContextCache({
      systemInstruction,
      contents,
      model,
      fingerprint,
      prefixTokens,
    });

    const response = await withRetry(async (client) => {
      const generative = client.getGenerativeModel({
        model,
        systemInstruction,
        generationConfig: { maxOutputTokens: maxTokens, temperature },
      });
      const req = { contents };
      if (cachedContent) req.cachedContent = cachedContent;
      return generative.generateContent(req);
    });

    const text = adapters.extractText(response);
    const usage = adapters.normalizeUsage(response);
    return { text, model, usage, cost: costFor(model, usage), raw: response };
  }

  async function analyzeImages({
    messages,
    imageUrls,
    userId,
    model = cfg.models?.vision || 'gemini-2.5-flash',
  }) {
    const m = Array.isArray(messages) ? [...messages] : [];
    const last = m.pop() || { role: 'user', content: 'Analyze the attached crop image(s).' };
    const textPart = {
      type: 'text',
      text: typeof last.content === 'string' ? last.content : 'Analyze the attached crop image(s).',
    };
    const imageParts = (imageUrls || []).map((url) => ({
      type: 'image_url',
      image_url: { url, detail: 'low' },
    }));
    m.push({ role: 'user', content: [textPart, ...imageParts] });

    return chat({ messages: m, model, userId, maxTokens: 900, temperature: 0.2 });
  }

  async function embed({ input, model = cfg.models?.embed || 'text-embedding-005' }) {
    const items = Array.isArray(input) ? input : [input];
    const response = await withRetry(async (client) => {
      const generative = client.getGenerativeModel({ model });
      const instances = items.map((t) => ({ content: t }));
      if (typeof generative.embedContent === 'function') {
        return Promise.all(items.map((t) => generative.embedContent({ content: { parts: [{ text: t }] } })));
      }
      if (typeof generative.embed === 'function') {
        return generative.embed({ instances });
      }
      throw new Error('vertex embed: generative model has no embed API');
    });
    const data = Array.isArray(response)
      ? response.map((r) => ({ embedding: r?.embedding?.values || [] }))
      : (response?.predictions || []).map((p) => ({ embedding: p?.embeddings?.values || [] }));
    return { model, data, usage: {} };
  }

  function countTokens({ messages }) {
    return countMessageTokens(messages);
  }

  async function validate() {
    try {
      const client = clientFor(regions[0]);
      const generative = client.getGenerativeModel({
        model: cfg.models?.chat || 'gemini-2.5-flash',
      });
      if (typeof generative.countTokens === 'function') {
        await generative.countTokens({ contents: [{ role: 'user', parts: [{ text: 'ping' }] }] });
      }
      return { ok: true };
    } catch (err) {
      return {
        ok: false,
        code: err?.code || 'unknown',
        message: err?.message || 'validation failed',
      };
    }
  }

  return {
    provider: 'vertex',
    streamChat,
    chat,
    analyzeImages,
    embed,
    countTokens,
    validate,
  };
}

module.exports = { bind };
