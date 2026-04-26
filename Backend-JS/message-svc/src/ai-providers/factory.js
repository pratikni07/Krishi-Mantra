const AiConfig = require('../services/ai-config.service');
const redis = require('../config/redis');
const logger = require('../utils/logger');
const { assertImplements, ProviderUnavailable } = require('./provider.interface');

const openaiProvider = require('./openai.provider');

let vertexProvider = null;
try {
  vertexProvider = require('./vertex.provider');
} catch (err) {
  vertexProvider = null;
}

const KILLSWITCH_KEY = (p) => `ai:killswitch:${p}`;
const GLOBAL_KILLSWITCH = 'ai:killswitch:global';

let lastBound = null;
let lastBoundConfigId = null;

async function killswitchActive(provider) {
  try {
    const [global, perProvider] = await Promise.all([
      redis.get(GLOBAL_KILLSWITCH),
      redis.get(KILLSWITCH_KEY(provider)),
    ]);
    return global === '1' || perProvider === '1';
  } catch (err) {
    return false;
  }
}

function resolveModule(provider) {
  switch (provider) {
    case 'openai':
      return openaiProvider;
    case 'vertex':
      if (!vertexProvider) {
        throw new ProviderUnavailable('vertex', 'provider module not installed');
      }
      return vertexProvider;
    default:
      throw new ProviderUnavailable(provider, 'unknown provider');
  }
}

async function active() {
  const cfg = await AiConfig.getActive();
  if (!cfg) throw new ProviderUnavailable('none', 'no active AiProviderConfig');

  if (await killswitchActive(cfg.provider)) {
    logger.warn('provider killswitch active', { provider: cfg.provider });
    throw new ProviderUnavailable(cfg.provider, 'killswitch active');
  }

  if (lastBound && String(lastBoundConfigId) === String(cfg._id)) return lastBound;

  const mod = resolveModule(cfg.provider);
  const instance = assertImplements(mod.bind(cfg), cfg.provider);
  lastBound = instance;
  lastBoundConfigId = cfg._id;
  return instance;
}

function resetCache() {
  lastBound = null;
  lastBoundConfigId = null;
}

module.exports = { active, resetCache, killswitchActive };
