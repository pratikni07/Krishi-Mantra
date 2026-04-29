const axios = require('axios');

/**
 * Thin client for the standalone notification service. Anything that
 * happens server-side and should reach the user's phone (push,
 * in-app, digest) goes through here so we don't scatter the same
 * "axios.post(NOTIFICATION_SERVICE_URL/...)" boilerplate across every
 * domain controller.
 *
 * Calls are best-effort: a notification-service outage must not unwind
 * the originating action (subscription activation, marketplace create,
 * etc.). Failures are logged and swallowed.
 */
const TIMEOUT_MS = 5000;

function getBaseUrl() {
  return process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:3005';
}

/**
 * Fire-and-forget notification dispatch.
 *
 * @param {object} params
 * @param {string} params.userId  Recipient user id (omit for broadcast).
 * @param {string} params.title   Short headline.
 * @param {string} params.message Body text.
 * @param {string} params.type    Domain category (subscription, marketplace, ...).
 * @param {object} [params.data]  Arbitrary metadata for the client.
 * @param {string[]} [params.channels=['push','in_app']]
 */
function notify({ userId, title, message, type, data = {}, channels = ['push', 'in_app'] }) {
  // Defensive: don't block the caller. The promise is awaited inside this
  // helper but never rethrown — the caller should `void` it or fire-and-
  // forget without an `await`.
  return axios
    .post(
      `${getBaseUrl()}/api/notifications`,
      { userId, title, message, type, data, channels },
      { timeout: TIMEOUT_MS }
    )
    .then(() => true)
    .catch((err) => {
      console.error(
        '[notificationClient] dispatch failed:',
        err.response?.status || err.code || err.message
      );
      return false;
    });
}

module.exports = { notify };
