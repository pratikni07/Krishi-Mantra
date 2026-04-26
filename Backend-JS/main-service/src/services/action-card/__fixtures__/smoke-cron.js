/**
 * Cron logic smoke — verifies the time-window filter, slot keying, and the
 * worker-pool semantics in isolation. No DB, no Redis, no node-cron required.
 *
 * Runs offline:  node src/services/action-card/__fixtures__/smoke-cron.js
 */

const path = require('path');

function stub(modulePath, exportsObj) {
  const resolved = require.resolve(modulePath);
  require.cache[resolved] = {
    id: resolved, filename: resolved, loaded: true, exports: exportsObj,
  };
}

stub('../../../utils/logger', {
  info: () => {}, warn: () => {}, error: () => {}, debug: () => {},
});
stub('../../../config/redis', {
  get: async () => null, set: async () => 'OK', setex: async () => 'OK',
  del: async () => 1, client: null, isRedisAvailable: () => false,
});

// Stub out the model/builder requires so card.cron loads cleanly.
stub(path.resolve(__dirname, '../../../model/FarmProfile'), {
  find: () => ({ select: () => ({ lean: async () => [] }) }),
});
stub(path.resolve(__dirname, '../../../model/DailyActionCard'), {
  find: () => ({ select: () => ({ lean: async () => [] }) }),
});
stub(path.resolve(__dirname, '../card.builder'), {
  buildCardForUser: async () => ({ cardId: 'cid', items: [], generated: true }),
  todayLocalDate: () => new Date().toISOString().slice(0, 10),
});

const Cron = require('../card.cron');
const { withinNextWindow, slotKey, runPool, nextLocalOccurrence } = Cron._internal;

let passed = 0, failed = 0;
function ok(label, cond, extra = '') {
  if (cond) { passed += 1; console.log('  ✓ ' + label); }
  else { failed += 1; console.error('  ✗ ' + label + (extra ? ` — ${extra}` : '')); }
}

(async () => {
  console.log('--- Slot key bucketing');
  {
    const a = slotKey(new Date('2026-04-25T03:00:00Z'));
    const b = slotKey(new Date('2026-04-25T03:29:59Z'));
    const c = slotKey(new Date('2026-04-25T03:30:00Z'));
    ok('00:xx → :00 bucket', a.endsWith(':00'));
    ok('29:59 → :00 bucket', b.endsWith(':00'));
    ok(':30 → :30 bucket', c.endsWith(':30'));
    ok('different time → different slot', a !== c);
  }

  console.log('--- Time window: India IST');
  {
    // 02:00 UTC = 07:30 IST. User wants morning push at 07:00 IST = 01:30 UTC.
    // Their next 07:00 IST occurrence (relative to 02:00 UTC) is tomorrow 01:30 UTC,
    // i.e. ~23.5 hours away → NOT in the next 30-60 min window.
    const now = new Date('2026-04-25T02:00:00Z');
    const inWindow = withinNextWindow('07:00', 'Asia/Kolkata', 60, now);
    ok('07:00 IST not in window at 02:00 UTC', !inWindow);

    // 01:00 UTC = 06:30 IST. Next 07:00 IST occurs in 30 min — IN the window.
    const now2 = new Date('2026-04-25T01:00:00Z');
    const inWindow2 = withinNextWindow('07:00', 'Asia/Kolkata', 60, now2);
    ok('07:00 IST IS in 60-min window at 01:00 UTC', inWindow2);

    // 00:30 UTC = 06:00 IST. Next 07:00 IST is 60 min away — at the edge.
    const now3 = new Date('2026-04-25T00:30:00Z');
    const inWindow3 = withinNextWindow('07:00', 'Asia/Kolkata', 60, now3);
    ok('07:00 IST in 60-min window at 00:30 UTC', inWindow3);

    // 00:00 UTC = 05:30 IST. Next 07:00 IST is 90 min away — NOT in 60-min window.
    const now4 = new Date('2026-04-25T00:00:00Z');
    const inWindow4 = withinNextWindow('07:00', 'Asia/Kolkata', 60, now4);
    ok('07:00 IST not in window at 00:00 UTC', !inWindow4);
  }

  console.log('--- Time window: Different morning prefs');
  {
    // User who likes 5:30 AM IST = 00:00 UTC.
    const now = new Date('2026-04-24T23:00:00Z'); // 04:30 IST
    const inWindow = withinNextWindow('05:30', 'Asia/Kolkata', 60, now);
    ok('05:30 IST in 60-min window at 23:00 UTC prev day', inWindow);
  }

  console.log('--- Worker pool concurrency');
  {
    const items = Array.from({ length: 12 }, (_, i) => i);
    let inFlight = 0;
    let maxInFlight = 0;
    const { results, processed } = await runPool(items, async (n) => {
      inFlight += 1;
      maxInFlight = Math.max(maxInFlight, inFlight);
      await new Promise((r) => setTimeout(r, 10));
      inFlight -= 1;
      return n * 2;
    }, 4);
    ok('all 12 items processed', processed === 12);
    ok('results computed correctly', results.every((v, i) => v === i * 2));
    ok('max in-flight ≤ pool size', maxInFlight <= 4, `got max ${maxInFlight}`);
  }

  console.log('--- Pool with fewer items than concurrency');
  {
    const items = [1, 2];
    const { results, processed } = await runPool(items, async (n) => n + 100, 8);
    ok('2 items processed', processed === 2);
    ok('correct results', results[0] === 101 && results[1] === 102);
  }

  console.log('--- Pool with one worker throwing');
  {
    const items = [1, 2, 3];
    const { results, processed } = await runPool(items, async (n) => {
      if (n === 2) throw new Error('boom');
      return n;
    }, 2);
    ok('still completes 3 items', processed === 3);
    ok('failed item captured as error', results[1].error?.message === 'boom');
    ok('other items succeeded', results[0] === 1 && results[2] === 3);
  }

  console.log('--- nextLocalOccurrence wrap-around');
  {
    // 22:00 UTC = 03:30 IST next day (it crossed midnight). User wants 07:00 IST.
    // nextOccurrence should be ~3.5h later in UTC.
    const now = new Date('2026-04-25T22:00:00Z');
    const fire = nextLocalOccurrence('07:00', 'Asia/Kolkata', now);
    const diffMin = Math.round((fire.getTime() - now.getTime()) / 60_000);
    ok('07:00 IST after 03:30 IST is +3.5h', diffMin >= 200 && diffMin <= 220, `got ${diffMin}min`);
  }

  console.log('--- Default morning time fallback');
  {
    const now = new Date('2026-04-25T00:30:00Z');
    const inWindow = withinNextWindow('garbage', 'Asia/Kolkata', 60, now);
    // 'garbage' should fall through to default '07:00' → 30 min before is in window.
    ok('invalid time string falls back to 07:00', inWindow);
  }

  console.log(`\nResults: ${passed} passed, ${failed} failed`);
  process.exit(failed === 0 ? 0 : 1);
})().catch((err) => {
  console.error('Smoke crashed:', err);
  process.exit(1);
});
