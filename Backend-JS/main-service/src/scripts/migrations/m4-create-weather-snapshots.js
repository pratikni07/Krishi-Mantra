/**
 * M4 — create `weather_snapshots` collection + TTL index.
 * The model itself lives in message-svc; this migration runs against the same DB
 * and just ensures the collection + TTL index exist before message-svc boots.
 *
 * Usage: node src/scripts/migrations/m4-create-weather-snapshots.js
 */
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.resolve(__dirname, '../../../.env.development') });
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

const mongoose = require('mongoose');

async function up() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/farmer-chat');
  const db = mongoose.connection.db;

  const existing = await db.listCollections({ name: 'weathersnapshots' }).toArray();
  if (!existing.length) {
    await db.createCollection('weathersnapshots');
  }
  const coll = db.collection('weathersnapshots');
  await coll.createIndex({ bucket: 1 }, { unique: true });
  await coll.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 });

  const idx = await coll.indexes();
  console.log('[M4] weather_snapshots indexes:', idx.map((i) => i.name).join(', '));

  await mongoose.disconnect();
  console.log('[M4] done');
}

async function down() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/farmer-chat');
  await mongoose.connection.db.dropCollection('weathersnapshots').catch(() => {});
  await mongoose.disconnect();
  console.log('[M4] rolled back');
}

if (require.main === module) {
  const dir = process.argv[2] === 'down' ? down : up;
  dir().catch((err) => {
    console.error('[M4] failed:', err.message);
    process.exit(1);
  });
}

module.exports = { up, down };
