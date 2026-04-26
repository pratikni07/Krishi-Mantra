const crypto = require('crypto');

const ALGO = 'aes-256-gcm';
const IV_BYTES = 12;
const KEY_BYTES = 32;

function loadMasterKey() {
  const raw = process.env.AI_CONFIG_MASTER_KEY;
  if (!raw) {
    throw new Error(
      'AI_CONFIG_MASTER_KEY is not set. Generate a 32-byte base64 key and set in env.'
    );
  }
  const key = Buffer.from(raw, 'base64');
  if (key.length !== KEY_BYTES) {
    throw new Error(`AI_CONFIG_MASTER_KEY must decode to ${KEY_BYTES} bytes (got ${key.length}).`);
  }
  return key;
}

function keyAlias() {
  return process.env.AI_CONFIG_KEK_ALIAS || 'local';
}

function encrypt(plaintext, { aad } = {}) {
  const key = loadMasterKey();
  const iv = crypto.randomBytes(IV_BYTES);
  const cipher = crypto.createCipheriv(ALGO, key, iv);
  if (aad) cipher.setAAD(Buffer.from(aad, 'utf8'));
  const ct = Buffer.concat([cipher.update(Buffer.from(plaintext, 'utf8')), cipher.final()]);
  const tag = cipher.getAuthTag();
  return {
    iv: iv.toString('base64'),
    tag: tag.toString('base64'),
    ciphertext: ct.toString('base64'),
    kekAlias: keyAlias(),
  };
}

function decrypt(blob, { aad } = {}) {
  if (!blob || !blob.iv || !blob.tag || !blob.ciphertext) {
    throw new Error('secret-box: invalid blob shape');
  }
  const key = loadMasterKey();
  const iv = Buffer.from(blob.iv, 'base64');
  const tag = Buffer.from(blob.tag, 'base64');
  const ct = Buffer.from(blob.ciphertext, 'base64');
  const decipher = crypto.createDecipheriv(ALGO, key, iv);
  if (aad) decipher.setAAD(Buffer.from(aad, 'utf8'));
  decipher.setAuthTag(tag);
  const pt = Buffer.concat([decipher.update(ct), decipher.final()]);
  return pt.toString('utf8');
}

function fingerprint(plaintext) {
  return crypto.createHash('sha256').update(plaintext, 'utf8').digest('hex');
}

function generateMasterKey() {
  return crypto.randomBytes(KEY_BYTES).toString('base64');
}

module.exports = { encrypt, decrypt, fingerprint, generateMasterKey };
