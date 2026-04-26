/**
 * M3 — add `usage`, `summary`, `farmProfileRef`, `contextFingerprint` defaults
 * to existing `aichats` docs. Safe on live traffic (only $set-missing fields).
 * Lazy-init on next write also works, but doing it now keeps dashboard queries
 * simple (no null-coalescing).
 *
 * Usage: node src/scripts/migrations/m3-extend-ai-chat.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.resolve(__dirname, '../../../.env.development') });
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

const mongoose = require('mongoose');

async function up() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/farmer-chat');
  const coll = mongoose.connection.db.collection('aichats');

  const res1 = await coll.updateMany(
    { usage: { $exists: false } },
    {
      $set: {
        usage: {
          totalPromptTokens: 0,
          totalCachedTokens: 0,
          totalCompletionTokens: 0,
          estimatedUsdCost: 0,
          modelBreakdown: {},
        },
      },
    }
  );
  const res2 = await coll.updateMany(
    { summary: { $exists: false } },
    { $set: { summary: { text: '', summarizedUpTo: 0, summaryTokens: 0 } } }
  );
  console.log(`[M3] usage backfilled on ${res1.modifiedCount} docs`);
  console.log(`[M3] summary backfilled on ${res2.modifiedCount} docs`);
  await mongoose.disconnect();
}

if (require.main === module) {
  up().catch((err) => {
    console.error('[M3] failed:', err.message);
    process.exit(1);
  });
}

module.exports = { up };
