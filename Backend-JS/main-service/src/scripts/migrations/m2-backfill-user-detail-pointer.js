/**
 * M2 — for every UserDetail without a farmProfile pointer, create an empty
 * FarmProfile (onboardingStatus: "not_started") and point UserDetail.farmProfile at it.
 * Idempotent: skips users who already have a pointer.
 *
 * Usage: node src/scripts/migrations/m2-backfill-user-detail-pointer.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.resolve(__dirname, '../../../.env.development') });
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

const mongoose = require('mongoose');
const UserDetail = require('../../model/UserDetail');
const FarmProfile = require('../../model/FarmProfile');

const BATCH = 500;

async function up() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/farmer-chat');
  console.log('[M2] connected');

  let processed = 0;
  let created = 0;
  let skipped = 0;

  const cursor = UserDetail.find({ farmProfile: { $in: [null, undefined] } }).cursor();
  let batch = [];
  for (let detail = await cursor.next(); detail != null; detail = await cursor.next()) {
    batch.push(detail);
    if (batch.length >= BATCH) {
      const stats = await flush(batch);
      created += stats.created;
      skipped += stats.skipped;
      processed += batch.length;
      batch = [];
      console.log(`[M2] processed ${processed} (created=${created}, skipped=${skipped})`);
    }
  }
  if (batch.length) {
    const stats = await flush(batch);
    created += stats.created;
    skipped += stats.skipped;
    processed += batch.length;
  }

  console.log(`[M2] done. processed=${processed} created=${created} skipped=${skipped}`);
  await mongoose.disconnect();
}

async function flush(details) {
  let created = 0;
  let skipped = 0;
  for (const detail of details) {
    if (!detail.userId) {
      skipped += 1;
      continue;
    }
    const existing = await FarmProfile.findOne({ userId: detail.userId }).select('_id').lean();
    let profileId = existing?._id;
    if (!profileId) {
      const profile = await FarmProfile.create({
        userId: detail.userId,
        onboardingStatus: 'not_started',
      });
      profileId = profile._id;
      created += 1;
    } else {
      skipped += 1;
    }
    detail.farmProfile = profileId;
    await detail.save();
  }
  return { created, skipped };
}

if (require.main === module) {
  up().catch((err) => {
    console.error('[M2] failed:', err.message);
    process.exit(1);
  });
}

module.exports = { up };
