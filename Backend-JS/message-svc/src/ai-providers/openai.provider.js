let OpenAI;
try {
  OpenAI = require('openai');
} catch (err) {
  OpenAI = null;
}

const logger = require('../utils/logger');
const { costFor } = require('../utils/cost-table');

const RETRYABLE_STATUS = new Set([408, 409, 429, 500, 502, 503, 504]);

function approxTokenCount(text) {
  if (!text) return 0;
  return Math.ceil(String(text).length / 4);
}

function countMessageTokens(messages) {
  let total = 0;
  for (const m of messages || []) {
    total += 4;
    if (!m || m.content == null) continue;
    if (typeof m.content === 'string') {
      total += approxTokenCount(m.content);
    } else if (Array.isArray(m.content)) {
      for (const part of m.content) {
        if (part?.type === 'text' && part.text) total += approxTokenCount(part.text);
        else if (part?.type === 'image_url') total += 85;
      }
    }
  }
  return total + 2;
}

function bind(cfg) {
  if (!OpenAI) {
    throw new Error('openai SDK not installed. Run `npm install openai` in message-svc.');
  }

  const apiKeys = Array.isArray(cfg?.credentials?.apiKeys) ? cfg.credentials.apiKeys : [];
  if (!apiKeys.length) {
    throw new Error('OpenAI config has no API keys');
  }

  let keyIndex = 0;
  const extras = cfg.extras || {};

  const client = () =>
    new OpenAI({
      apiKey: apiKeys[keyIndex],
      organization: extras.orgId,
      baseURL: extras.baseUrl,
      timeout: 60_000,
      maxRetries: 0,
    });

  async function withRetry(fn, { max = 4 } = {}) {
    let lastErr;
    for (let attempt = 0; attempt < max; attempt++) {
      try {
        return await fn(client());
      } catch (err) {
        lastErr = err;
        const status = err?.status ?? err?.response?.status;
        if (!RETRYABLE_STATUS.has(status)) throw err;
        if (status === 429 && apiKeys.length > 1) {
          keyIndex = (keyIndex + 1) % apiKeys.length;
        }
        const backoff = Math.min(10_000, 2 ** attempt * 500 + Math.random() * 250);
        logger.warn('openai retry', { attempt: attempt + 1, status, backoff });
        await new Promise((r) => setTimeout(r, backoff));
      }
    }
    throw lastErr;
  }

  async function* normalizeStream(stream) {
    let usage = null;
    try {
      for await (const chunk of stream) {
        if (chunk.usage) usage = chunk.usage;
        const delta = chunk.choices?.[0]?.delta?.content;
        if (delta) yield { type: 'delta', text: delta };
      }
      yield { type: 'done', usage: usage || {} };
    } catch (err) {
      yield { type: 'error', code: err?.code || 'stream_error', message: err.message };
    }
  }

  async function streamChat({
    messages,
    model = cfg.models.chat,
    userId,
    maxTokens = 800,
    temperature = 0.4,
    abortSignal,
  }) {
    const stream = await withRetry(async (c) =>
      c.chat.completions.create(
        {
          model,
          messages,
          stream: true,
          max_tokens: maxTokens,
          temperature,
          user: userId,
          stream_options: { include_usage: true },
        },
        { signal: abortSignal }
      )
    );
    return normalizeStream(stream);
  }

  async function chat({
    messages,
    model = cfg.models.chat,
    userId,
    maxTokens = 400,
    temperature = 0.3,
  }) {
    const response = await withRetry(async (c) =>
      c.chat.completions.create({
        model,
        messages,
        max_tokens: maxTokens,
        temperature,
        user: userId,
      })
    );
    return {
      text: response.choices?.[0]?.message?.content || '',
      model,
      usage: response.usage || {},
      cost: costFor(model, response.usage || {}),
      raw: response,
    };
  }

  async function analyzeImages({
    messages,
    imageUrls,
    userId,
    model = cfg.models.vision,
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

    const response = await withRetry(async (c) =>
      c.chat.completions.create({
        model,
        messages: m,
        max_tokens: 900,
        temperature: 0.2,
        user: userId,
      })
    );
    return {
      text: response.choices?.[0]?.message?.content || '',
      model,
      usage: response.usage || {},
      cost: costFor(model, response.usage || {}),
      raw: response,
    };
  }

  async function embed({ input, model = cfg.models.embed }) {
    const response = await withRetry(async (c) => c.embeddings.create({ model, input }));
    return {
      model,
      data: response.data || [],
      usage: response.usage || {},
    };
  }

  function countTokens({ messages }) {
    return countMessageTokens(messages);
  }

  async function validate() {
    try {
      const c = client();
      await c.models.list();
      return { ok: true };
    } catch (err) {
      return {
        ok: false,
        code: err?.status || 'unknown',
        message: err?.message || 'validation failed',
      };
    }
  }

  return {
    provider: 'openai',
    streamChat,
    chat,
    analyzeImages,
    embed,
    countTokens,
    validate,
  };
}

module.exports = { bind };
