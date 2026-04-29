/**
 * FCM (Firebase Cloud Messaging) provider.
 *
 * Lazily initialises the firebase-admin SDK on first use so the service
 * can boot in environments where push isn't configured (CI, dev without
 * credentials) without crashing — those environments fall back to the
 * existing in-app + websocket delivery and the push channel reports
 * `enabled=false`.
 *
 * Credentials are loaded from one of:
 *   1. FIREBASE_SERVICE_ACCOUNT_JSON  — full JSON blob in env (k8s secret)
 *   2. FIREBASE_SERVICE_ACCOUNT_PATH  — filesystem path to credentials JSON
 *   3. GOOGLE_APPLICATION_CREDENTIALS — standard Google ADC env var
 *
 * Token cleanup: when FCM rejects a token as `registration-token-not-registered`
 * or `invalid-argument`, we surface that to the caller so the user
 * preferences row can clear the dead token. Otherwise stale uninstall
 * tokens accumulate and we waste calls every send.
 */

const logger = require('../utils/logger');

let admin = null;
let app = null;
let initialised = false;
let initFailed = false;

function _loadCredentials() {
  const inlineJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (inlineJson && inlineJson.trim()) {
    try {
      return JSON.parse(inlineJson);
    } catch (e) {
      logger.error('FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON; ignoring.');
    }
  }
  const explicitPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (explicitPath && explicitPath.trim()) {
    try {
      // eslint-disable-next-line global-require
      return require(explicitPath);
    } catch (e) {
      logger.error(`Failed to load FIREBASE_SERVICE_ACCOUNT_PATH (${explicitPath}): ${e.message}`);
    }
  }
  return null;
}

function _ensureInitialised() {
  if (initialised || initFailed) return;
  try {
    // eslint-disable-next-line global-require
    admin = require('firebase-admin');
  } catch (e) {
    logger.warn('firebase-admin not installed; FCM push delivery is disabled.');
    initFailed = true;
    return;
  }
  try {
    if (admin.apps && admin.apps.length > 0) {
      app = admin.apps[0];
    } else {
      const creds = _loadCredentials();
      if (creds) {
        app = admin.initializeApp({ credential: admin.credential.cert(creds) });
      } else {
        // Falls back to ADC / GOOGLE_APPLICATION_CREDENTIALS.
        app = admin.initializeApp();
      }
    }
    initialised = true;
    logger.info('FCM provider initialised');
  } catch (e) {
    logger.error('FCM provider initialisation failed:', e.message);
    initFailed = true;
  }
}

function isAvailable() {
  _ensureInitialised();
  return initialised && !initFailed;
}

/**
 * Send a single push to one device token.
 *
 * Returns:
 *   { ok: true, messageId }
 *   { ok: false, retryable: boolean, invalidToken: boolean, error: string }
 *
 * `invalidToken=true` is the signal to caller: clear this token from
 * preferences. `retryable=true` means the failure was transient (rate
 * limit, server error) and a later retry might succeed.
 */
async function sendToToken({ token, title, body, data = {}, category }) {
  _ensureInitialised();
  if (!initialised) {
    return { ok: false, retryable: false, invalidToken: false, error: 'FCM not initialised' };
  }
  if (!token) {
    return { ok: false, retryable: false, invalidToken: false, error: 'no-token' };
  }

  // FCM data-payload fields must all be strings. Coerce to strings here
  // so the caller can pass numbers/booleans without crashing the SDK.
  const stringifiedData = {};
  for (const [k, v] of Object.entries(data || {})) {
    if (v === null || v === undefined) continue;
    stringifiedData[k] = typeof v === 'string' ? v : JSON.stringify(v);
  }

  const message = {
    token,
    notification: { title, body },
    data: stringifiedData,
    android: {
      priority: 'high',
      notification: {
        channelId: category || 'default',
      },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: {
        aps: {
          alert: { title, body },
          sound: 'default',
        },
      },
    },
  };

  try {
    const messageId = await admin.messaging().send(message);
    return { ok: true, messageId };
  } catch (err) {
    const code = err?.errorInfo?.code || err?.code || '';
    const invalidToken =
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token' ||
      code === 'messaging/invalid-argument';
    const retryable =
      code === 'messaging/internal-error' ||
      code === 'messaging/server-unavailable' ||
      code === 'messaging/quota-exceeded';
    return {
      ok: false,
      retryable,
      invalidToken,
      error: code || err.message || 'unknown',
    };
  }
}

module.exports = { isAvailable, sendToToken };
