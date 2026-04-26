/**
 * M-A1 — create action-card collections + indexes.
 *
 * Idempotent: re-runnable. Each `syncIndexes` call only creates missing indexes.
 *
 * Usage: node src/scripts/migrations/m-A1-create-action-card-collections.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.resolve(__dirname, '../../../.env.development') });
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

const mongoose = require('mongoose');
const CropTaskTemplate = require('../../model/CropTaskTemplate');
const DailyActionCard = require('../../model/DailyActionCard');
const ActivityJournal = require('../../model/ActivityJournal');

async function up() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/farmer-chat');
  console.log('[M-A1] connected');

  for (const Model of [CropTaskTemplate, DailyActionCard, ActivityJournal]) {
    await Model.createCollection();
    await Model.syncIndexes();
    const idx = await Model.collection.indexes();
    console.log(
      `[M-A1] ${Model.collection.collectionName} indexes:`,
      idx.map((i) => i.name).join(', ')
    );
  }

  await mongoose.disconnect();
  console.log('[M-A1] done');
}

async function down() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/farmer-chat');
  for (const name of ['croptasktemplates', 'dailyactioncards', 'activityjournals']) {
    await mongoose.connection.db.dropCollection(name).catch(() => {});
  }
  await mongoose.disconnect();
  console.log('[M-A1] rolled back');
}

if (require.main === module) {
  const dir = process.argv[2] === 'down' ? down : up;
  dir().catch((err) => {
    console.error('[M-A1] failed:', err.message);
    process.exit(1);
  });
}

module.exports = { up, down };
