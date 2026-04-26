/**
 * M-A3 — backfill `FarmProfile.notifyPrefs` defaults on docs that don't have them.
 * Safe on live traffic; only $set-missing fields. Re-runnable.
 *
 * Usage: node src/scripts/migrations/m-A3-backfill-notify-prefs.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.resolve(__dirname, '../../../.env.development') });
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

const mongoose = require('mongoose');

async function up() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/farmer-chat');
  const coll = mongoose.connection.db.collection('farmprofiles');

  const tzRes = await coll.updateMany(
    { timezone: { $exists: false } },
    { $set: { timezone: 'Asia/Kolkata' } }
  );

  const npRes = await coll.updateMany(
    { notifyPrefs: { $exists: false } },
    {
      $set: {
        notifyPrefs: {
          morningCardEnabled: true,
          morningCardLocalTime: '07:00',
          weatherAlertsEnabled: true,
          preferredChannel: 'push',
        },
      },
    }
  );

  console.log(`[M-A3] timezone backfilled on ${tzRes.modifiedCount} docs`);
  console.log(`[M-A3] notifyPrefs backfilled on ${npRes.modifiedCount} docs`);

  await mongoose.disconnect();
}

if (require.main === module) {
  up().catch((err) => {
    console.error('[M-A3] failed:', err.message);
    process.exit(1);
  });
}

module.exports = { up };
