#!/usr/bin/env node
/**
 * API smoke test
 *
 * Hits a curated list of endpoints used by the Flutter client and asserts
 * each one returns a non-5xx, non-404 status. Catches contract drift between
 * frontend and backend (path typos, removed routes, wrong service mounts).
 *
 * Usage:
 *   API_BASE_URL=https://api.krishimantra.com \
 *   AUTH_TOKEN=eyJ... \
 *   TEST_USER_ID=64f... \
 *   node smoke-test.js
 *
 * Exit codes:
 *   0 — all endpoints OK
 *   1 — at least one endpoint failed (5xx, 404, or unreachable)
 *   2 — config missing
 */

const https = require('https');
const http = require('http');
const url = require('url');

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:3001';
const AUTH_TOKEN = process.env.AUTH_TOKEN || '';
const TEST_USER_ID = process.env.TEST_USER_ID || '000000000000000000000000';
const TEST_FEED_ID = process.env.TEST_FEED_ID || '';
const TEST_REEL_ID = process.env.TEST_REEL_ID || '';
const TEST_PRODUCT_ID = process.env.TEST_PRODUCT_ID || '';
const TEST_CROP_ID = process.env.TEST_CROP_ID || '';

if (!AUTH_TOKEN) {
  console.error('AUTH_TOKEN is required. Pass a valid Bearer token via env.');
  process.exit(2);
}

// Each endpoint: { path, requiresAuth, expectStatuses, fixtures }
// expectStatuses defaults to anything < 500 and not 404.
// Use fixtures: ['REEL_ID'] to mark endpoints that depend on a runtime ID;
// they'll be skipped if the corresponding env var is absent.
const ENDPOINTS = [
  // Auth (cheap protected endpoint — confirms token is good)
  { path: '/api/main/auth/me', name: 'auth:me' },
  { path: '/api/v1/main/auth/me', name: 'auth:me:v1' },

  // Subscription
  { path: '/api/main/subscription/plans', name: 'subscription:plans' },
  { path: '/api/main/subscription/current', name: 'subscription:current' },
  { path: '/api/main/subscription/usage', name: 'subscription:usage' },
  { path: '/api/main/subscription/iot/addons', name: 'subscription:iot:addons' },
  { path: '/api/main/subscription/iot/my-addons', name: 'subscription:iot:my-addons' },
  { path: '/api/main/subscription/feature/aiChat', name: 'subscription:feature' },

  // Marketplace categories (server-driven)
  { path: '/api/main/marketplace/categories', name: 'marketplace:categories' },

  // Crop calendar
  { path: '/api/main/crop-calendar/crops', name: 'crop-calendar:crops' },
  {
    path: () => `/api/main/crop-calendar/calendar/${TEST_CROP_ID}/${new Date().getMonth() + 1}`,
    name: 'crop-calendar:calendar',
    fixtures: ['TEST_CROP_ID'],
  },

  // Marketplace
  { path: '/api/main/marketplace', name: 'marketplace:list' },
  { path: '/api/main/marketplace/search', name: 'marketplace:search' },
  { path: '/api/main/marketplace/trending-tags', name: 'marketplace:trending-tags' },
  {
    path: () => `/api/main/marketplace/${TEST_PRODUCT_ID}`,
    name: 'marketplace:detail',
    fixtures: ['TEST_PRODUCT_ID'],
  },

  // Feed
  { path: '/api/feed/feeds/getoptwo', name: 'feed:top' },
  { path: '/api/feed/feeds/random', name: 'feed:random' },
  { path: '/api/feed/feeds/trending/hashtags', name: 'feed:trending-hashtags' },
  { path: () => `/api/feed/feeds/user/${TEST_USER_ID}/recommended`, name: 'feed:recommended' },
  { path: () => `/api/feed/likes/user/${TEST_USER_ID}`, name: 'feed:user-likes' },

  // Reels
  { path: '/api/reels/trending', name: 'reels:trending' },
  { path: '/api/reels/tags/trending', name: 'reels:tags:trending' },
  { path: () => `/api/reels/recommended/${TEST_USER_ID}`, name: 'reels:recommended' },
  { path: () => `/api/reels/interests/${TEST_USER_ID}`, name: 'reels:interests' },
  {
    path: () => `/api/reels/${TEST_REEL_ID}`,
    name: 'reels:detail',
    fixtures: ['TEST_REEL_ID'],
  },
  {
    path: () => `/api/reels/${TEST_REEL_ID}/comments`,
    name: 'reels:comments',
    fixtures: ['TEST_REEL_ID'],
  },

  // Ads
  { path: '/api/main/ads/home-ads', name: 'ads:home' },
  { path: '/api/main/ads/feed-ads', name: 'ads:feed' },
  { path: '/api/main/ads/reel-ads', name: 'ads:reel' },
  { path: '/api/main/ads/splash-modal', name: 'ads:splash-modal' },
  { path: '/api/main/ads/home-screen-ads', name: 'ads:home-screen' },

  // Notification
  { path: '/api/notification', name: 'notification:list' },

  // Companies / products
  { path: '/api/main/companies', name: 'companies:list' },
  { path: '/api/main/products', name: 'products:list' },

  // Schemes
  { path: '/api/main/schemes', name: 'schemes:list' },

  // User / consultant
  { path: '/api/main/user/consultant', name: 'user:consultant' },

  // Upload
  { path: '/api/upload/contentTypes', name: 'upload:content-types' },
];

const fixturesOf = (env) => {
  switch (env) {
    case 'TEST_USER_ID': return TEST_USER_ID && TEST_USER_ID !== '000000000000000000000000';
    case 'TEST_REEL_ID': return !!TEST_REEL_ID;
    case 'TEST_FEED_ID': return !!TEST_FEED_ID;
    case 'TEST_PRODUCT_ID': return !!TEST_PRODUCT_ID;
    case 'TEST_CROP_ID': return !!TEST_CROP_ID;
    default: return true;
  }
};

const requestOnce = (fullUrl, { withAuth = true } = {}) =>
  new Promise((resolve) => {
    const parsed = url.parse(fullUrl);
    const transport = parsed.protocol === 'https:' ? https : http;
    const headers = { 'User-Agent': 'krishimantra-smoke-test' };
    if (withAuth) headers.Authorization = `Bearer ${AUTH_TOKEN}`;
    const req = transport.request(
      {
        hostname: parsed.hostname,
        port: parsed.port,
        path: parsed.path,
        method: 'GET',
        headers,
        timeout: 15000,
      },
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          resolve({
            status: res.statusCode,
            body: Buffer.concat(chunks).toString().slice(0, 200),
          });
        });
      }
    );
    req.on('error', (err) => resolve({ status: 0, body: err.message }));
    req.on('timeout', () => {
      req.destroy();
      resolve({ status: 0, body: 'timeout' });
    });
    req.end();
  });

// Negative-auth probes — confirm protected endpoints actually reject an
// unauthenticated request. The Phase 1 audit found mutate routes mounted
// without auth middleware; this catches a regression where someone removes
// auth from a route accidentally.
const NEGATIVE_AUTH_PATHS = [
  '/api/main/auth/me',
  '/api/main/subscription/current',
  '/api/main/subscription/usage',
  '/api/main/subscription/iot/my-addons',
];

const run = async () => {
  const results = { ok: 0, fail: 0, skip: 0, details: [] };

  for (const ep of ENDPOINTS) {
    const path = typeof ep.path === 'function' ? ep.path() : ep.path;
    const missing = (ep.fixtures || []).find((f) => !fixturesOf(f));
    if (missing) {
      results.skip++;
      results.details.push({ name: ep.name, path, status: 'SKIP', reason: `${missing} not set` });
      continue;
    }
    const fullUrl = BASE_URL.replace(/\/$/, '') + path;
    const { status, body } = await requestOnce(fullUrl);
    const acceptable = status >= 200 && status < 500 && status !== 404;
    if (acceptable) {
      results.ok++;
      results.details.push({ name: ep.name, path, status });
    } else {
      results.fail++;
      results.details.push({ name: ep.name, path, status, body });
    }
  }

  // Negative-auth pass — every protected route should 401 without a token.
  for (const path of NEGATIVE_AUTH_PATHS) {
    const fullUrl = BASE_URL.replace(/\/$/, '') + path;
    const { status, body } = await requestOnce(fullUrl, { withAuth: false });
    const expected = status === 401 || status === 403;
    const name = `negative-auth ${path}`;
    if (expected) {
      results.ok++;
      results.details.push({ name, path, status });
    } else {
      results.fail++;
      results.details.push({
        name,
        path,
        status,
        body: `expected 401/403 without token, got ${status}: ${body}`,
      });
    }
  }

  for (const d of results.details) {
    const tag = d.status === 'SKIP' ? 'SKIP' : (typeof d.status === 'number' && d.status >= 200 && d.status < 500 && d.status !== 404 ? ' OK ' : 'FAIL');
    console.log(`[${tag}] ${d.status}\t${d.name}\t${d.path}${d.body ? `\n        ${d.body}` : ''}${d.reason ? ` (${d.reason})` : ''}`);
  }
  console.log(`\n${results.ok} ok, ${results.fail} fail, ${results.skip} skip`);
  process.exit(results.fail > 0 ? 1 : 0);
};

run().catch((err) => {
  console.error('Smoke test crashed:', err);
  process.exit(1);
});
