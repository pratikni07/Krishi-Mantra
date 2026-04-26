const mongoose = require('mongoose');
const AiProviderConfig = require('../model/AiProviderConfig');
const AiProviderAudit = require('../model/AiProviderAudit');
const secretBox = require('../utils/secret-box');
const { asyncHandler } = require('../utils');
const { HTTP_STATUS } = require('../utils/constants');
const redis = require('../config/redis');

const PUBSUB_CHANNEL = 'ai-config.changed';

function redactConfig(doc) {
  if (!doc) return null;
  const plain = typeof doc.toObject === 'function' ? doc.toObject() : { ...doc };
  if (plain.credentials) {
    plain.credentials = {
      type: plain.credentials.type,
      fingerprint: plain.credentials.fingerprint,
      lastRotatedAt: plain.credentials.lastRotatedAt,
      keyCount: plain.extras?.keyCount,
    };
  }
  return plain;
}

async function writeAudit({ configId, provider, action, actor, diff, req }) {
  try {
    await AiProviderAudit.create({
      configId,
      provider,
      action,
      actor,
      diff,
      at: new Date(),
      ip: req?.ip,
      userAgent: req?.headers?.['user-agent'],
    });
  } catch (err) {
    // best-effort
  }
}

async function publishChange(payload = {}) {
  try {
    if (typeof redis.publish === 'function') {
      await redis.publish(PUBSUB_CHANNEL, payload);
    }
  } catch (err) {
    // best-effort
  }
}

exports.list = asyncHandler(async (req, res) => {
  const configs = await AiProviderConfig.find({}).sort({ isActive: -1, updatedAt: -1 }).lean();
  return res.status(HTTP_STATUS.OK).json({
    success: true,
    configs: configs.map(redactConfig),
  });
});

exports.getOne = asyncHandler(async (req, res) => {
  const { id } = req.params;
  if (!mongoose.Types.ObjectId.isValid(id)) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({ success: false, message: 'Invalid id' });
  }
  const doc = await AiProviderConfig.findById(id).lean();
  if (!doc) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({ success: false, message: 'Not found' });
  }
  return res.status(HTTP_STATUS.OK).json({ success: true, config: redactConfig(doc) });
});

exports.upsertOpenAI = asyncHandler(async (req, res) => {
  const actor = req.user?.id || req.user?._id;
  const { id, displayName, apiKeys, models, extras } = req.body || {};
  const keyList = Array.isArray(apiKeys)
    ? apiKeys.map((k) => String(k).trim()).filter(Boolean)
    : String(apiKeys || '')
        .split(/[\n,]/)
        .map((k) => k.trim())
        .filter(Boolean);

  if (!keyList.length) {
    return res
      .status(HTTP_STATUS.BAD_REQUEST)
      .json({ success: false, message: 'at least one apiKey is required' });
  }
  if (!models?.chat || !models?.vision || !models?.embed) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'models.chat, models.vision, models.embed are required',
    });
  }

  const plaintext = keyList.join('\n');
  let doc;
  if (id) {
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ success: false, message: 'Invalid id' });
    }
    doc = await AiProviderConfig.findById(id);
    if (!doc) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({ success: false, message: 'Not found' });
    }
    doc.displayName = displayName || doc.displayName;
    doc.models = { chat: models.chat, vision: models.vision, embed: models.embed };
    doc.credentials = {
      type: 'api_key',
      payload: secretBox.encrypt(plaintext, { aad: String(doc._id) }),
      fingerprint: secretBox.fingerprint(plaintext),
      lastRotatedAt: new Date(),
    };
    doc.extras = { ...(doc.extras || {}), ...(extras || {}), keyCount: keyList.length };
    doc.status = 'unvalidated';
    doc.lastValidatedAt = null;
    doc.lastError = null;
    doc.updatedBy = actor;
    await doc.save();
  } else {
    doc = new AiProviderConfig({
      provider: 'openai',
      displayName: displayName || 'OpenAI',
      models: { chat: models.chat, vision: models.vision, embed: models.embed },
      credentials: {
        type: 'api_key',
        payload: { iv: '', tag: '', ciphertext: '' },
        fingerprint: secretBox.fingerprint(plaintext),
        lastRotatedAt: new Date(),
      },
      extras: { ...(extras || {}), keyCount: keyList.length },
      status: 'unvalidated',
      createdBy: actor,
      updatedBy: actor,
    });
    doc.credentials.payload = secretBox.encrypt(plaintext, { aad: String(doc._id) });
    await doc.save();
  }

  await writeAudit({
    configId: doc._id,
    provider: 'openai',
    action: id ? 'update' : 'create',
    actor,
    diff: { models: doc.models, keyCount: keyList.length, extras: doc.extras },
    req,
  });
  if (doc.isActive) await publishChange({ configId: String(doc._id), action: 'update' });

  return res.status(HTTP_STATUS.OK).json({ success: true, config: redactConfig(doc) });
});

exports.upsertVertex = asyncHandler(async (req, res) => {
  const actor = req.user?.id || req.user?._id;
  const { id, displayName, serviceAccountJson, models, extras } = req.body || {};
  if (!serviceAccountJson) {
    return res
      .status(HTTP_STATUS.BAD_REQUEST)
      .json({ success: false, message: 'serviceAccountJson is required' });
  }
  const plaintext =
    typeof serviceAccountJson === 'string'
      ? serviceAccountJson
      : JSON.stringify(serviceAccountJson);
  try {
    JSON.parse(plaintext);
  } catch (err) {
    return res
      .status(HTTP_STATUS.BAD_REQUEST)
      .json({ success: false, message: 'serviceAccountJson is not valid JSON' });
  }
  if (!models?.chat || !models?.vision || !models?.embed) {
    return res
      .status(HTTP_STATUS.BAD_REQUEST)
      .json({ success: false, message: 'models.chat/vision/embed required' });
  }

  let doc;
  if (id) {
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ success: false, message: 'Invalid id' });
    }
    doc = await AiProviderConfig.findById(id);
    if (!doc) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({ success: false, message: 'Not found' });
    }
    doc.displayName = displayName || doc.displayName;
    doc.models = { chat: models.chat, vision: models.vision, embed: models.embed };
    doc.credentials = {
      type: 'service_account_json',
      payload: secretBox.encrypt(plaintext, { aad: String(doc._id) }),
      fingerprint: secretBox.fingerprint(plaintext),
      lastRotatedAt: new Date(),
    };
    doc.extras = { ...(doc.extras || {}), ...(extras || {}) };
    doc.status = 'unvalidated';
    doc.updatedBy = actor;
    await doc.save();
  } else {
    doc = new AiProviderConfig({
      provider: 'vertex',
      displayName: displayName || 'Google Vertex AI',
      models: { chat: models.chat, vision: models.vision, embed: models.embed },
      credentials: {
        type: 'service_account_json',
        payload: { iv: '', tag: '', ciphertext: '' },
        fingerprint: secretBox.fingerprint(plaintext),
        lastRotatedAt: new Date(),
      },
      extras: extras || {},
      status: 'unvalidated',
      createdBy: actor,
      updatedBy: actor,
    });
    doc.credentials.payload = secretBox.encrypt(plaintext, { aad: String(doc._id) });
    await doc.save();
  }

  await writeAudit({
    configId: doc._id,
    provider: 'vertex',
    action: id ? 'update' : 'create',
    actor,
    diff: { models: doc.models, extras: doc.extras },
    req,
  });
  if (doc.isActive) await publishChange({ configId: String(doc._id), action: 'update' });

  return res.status(HTTP_STATUS.OK).json({ success: true, config: redactConfig(doc) });
});

exports.activate = asyncHandler(async (req, res) => {
  const actor = req.user?.id || req.user?._id;
  const { id } = req.params;
  if (!mongoose.Types.ObjectId.isValid(id)) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({ success: false, message: 'Invalid id' });
  }

  const target = await AiProviderConfig.findById(id);
  if (!target) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({ success: false, message: 'Not found' });
  }

  const session = await mongoose.startSession();
  try {
    await session.withTransaction(async () => {
      await AiProviderConfig.updateMany(
        { _id: { $ne: target._id }, isActive: true },
        { $set: { isActive: false, updatedBy: actor } },
        { session }
      );
      target.isActive = true;
      target.updatedBy = actor;
      await target.save({ session });
    });
  } catch (err) {
    session.endSession();
    return res
      .status(HTTP_STATUS.INTERNAL_SERVER_ERROR || 500)
      .json({ success: false, message: err.message });
  }
  session.endSession();

  await writeAudit({
    configId: target._id,
    provider: target.provider,
    action: 'activate',
    actor,
    diff: { previouslyActive: false },
    req,
  });
  await publishChange({ configId: String(target._id), action: 'activate' });

  return res.status(HTTP_STATUS.OK).json({ success: true, config: redactConfig(target) });
});

exports.deactivateAll = asyncHandler(async (req, res) => {
  const actor = req.user?.id || req.user?._id;
  const result = await AiProviderConfig.updateMany(
    { isActive: true },
    { $set: { isActive: false, updatedBy: actor } }
  );
  await publishChange({ action: 'deactivate' });
  await writeAudit({
    configId: null,
    provider: 'openai',
    action: 'deactivate',
    actor,
    diff: { affected: result.modifiedCount },
    req,
  });
  return res.status(HTTP_STATUS.OK).json({ success: true, deactivated: result.modifiedCount });
});

exports.remove = asyncHandler(async (req, res) => {
  const actor = req.user?.id || req.user?._id;
  const { id } = req.params;
  if (!mongoose.Types.ObjectId.isValid(id)) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({ success: false, message: 'Invalid id' });
  }
  const doc = await AiProviderConfig.findById(id);
  if (!doc) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({ success: false, message: 'Not found' });
  }
  if (doc.isActive) {
    return res.status(HTTP_STATUS.BAD_REQUEST).json({
      success: false,
      message: 'Deactivate the config before deleting.',
    });
  }
  await AiProviderConfig.deleteOne({ _id: id });
  await writeAudit({
    configId: id,
    provider: doc.provider,
    action: 'delete',
    actor,
    diff: {},
    req,
  });
  return res.status(HTTP_STATUS.OK).json({ success: true, id });
});

exports.audit = asyncHandler(async (req, res) => {
  const { configId } = req.query;
  const filter = {};
  if (configId && mongoose.Types.ObjectId.isValid(configId)) filter.configId = configId;
  const entries = await AiProviderAudit.find(filter).sort({ at: -1 }).limit(100).lean();
  return res.status(HTTP_STATUS.OK).json({ success: true, audit: entries });
});
