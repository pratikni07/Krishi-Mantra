/**
 * M1 — create `farm_profiles` collection + indexes.
 * Usage: node src/scripts/migrations/m1-create-farm-profile.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.resolve(__dirname, '../../../.env.development') });
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

const mongoose = require('mongoose');
const FarmProfile = require('../../model/FarmProfile');

async function up() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/farmer-chat');
  console.log('[M1] connected');
  await FarmProfile.createCollection();
  await FarmProfile.syncIndexes();
  const idx = await FarmProfile.collection.indexes();
  console.log('[M1] farm_profiles indexes:', idx.map((i) => i.name).join(', '));
  await mongoose.disconnect();
  console.log('[M1] done');
}

async function down() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/farmer-chat');
  await mongoose.connection.db.dropCollection('farmprofiles').catch(() => {});
  await mongoose.disconnect();
  console.log('[M1] rolled back');
}

if (require.main === module) {
  const dir = process.argv[2] === 'down' ? down : up;
  dir().catch((err) => {
    console.error('[M1] failed:', err.message);
    process.exit(1);
  });
}

module.exports = { up, down };
