#!/usr/bin/env node

const path = require('path');
const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '../.env') });
dotenv.config({ path: path.resolve(__dirname, '../../main-service/.env') });

const Notification = require('../src/models/notification.model');

const MIN_NOTIFICATIONS_PER_USER = 50;
const BATCH_SIZE = 500;

const categories = [
  'system',
  'subscription',
  'promotion',
  'advertisement',
  'post_engagement',
  'reel_engagement',
  'marketplace',
  'consultant_service',
  'message',
  'new_post',
  'new_reel',
  'farm_videos',
  'crop_care_ai',
];

const priorities = ['low', 'medium', 'high'];
const statuses = ['delivered', 'read', 'pending'];

function rand(max) {
  return Math.floor(Math.random() * max);
}

function randomFrom(list) {
  return list[rand(list.length)];
}

function buildNotification(userId, index) {
  const category = randomFrom(categories);
  const createdAt = new Date(Date.now() - rand(1000 * 60 * 60 * 24 * 30));
  const status = randomFrom(statuses);
  const title = `Update #${index + 1}`;
  const body = `Sample notification ${index + 1} for user ${userId.slice(-6)}.`;

  const data = {
    type: category,
    source: 'seed_script',
    screen: category === 'message' ? 'ChatDetailScreen' : 'FeedDetailsScreen',
    feedId: `seed-feed-${rand(10000)}`,
    chatId: `seed-chat-${rand(10000)}`,
  };

  return {
    userId,
    type: 'in_app',
    title,
    body,
    data,
    status,
    priority: randomFrom(priorities),
    category,
    scheduledFor: createdAt,
    deliveredAt: status === 'delivered' || status === 'read' ? createdAt : null,
    seenAt: status === 'read' ? new Date(createdAt.getTime() + 60 * 1000) : null,
    createdAt,
    updatedAt: createdAt,
  };
}

async function run() {
  const notificationUri = process.env.MONGODB_URI;
  const mainUri = process.env.MONGODB_URL;

  if (!notificationUri) {
    throw new Error('Missing MONGODB_URI in notification-service/.env');
  }
  if (!mainUri) {
    throw new Error('Missing MONGODB_URL in main-service/.env');
  }

  const mainConn = mongoose.createConnection(mainUri, {
    serverSelectionTimeoutMS: 15000,
  });

  try {
    await mongoose.connect(notificationUri, {
      serverSelectionTimeoutMS: 15000,
    });
    await mainConn.asPromise();

    const users = await mainConn.collection('users').find({}, { projection: { _id: 1 } }).toArray();
    if (!users.length) {
      console.log('No users found. Nothing to seed.');
      return;
    }

    let insertedTotal = 0;
    let touchedUsers = 0;

    for (const user of users) {
      const userId = String(user._id);
      const existingCount = await Notification.countDocuments({ userId });
      const needed = Math.max(0, MIN_NOTIFICATIONS_PER_USER - existingCount);

      if (needed === 0) {
        continue;
      }

      const docs = Array.from({ length: needed }, (_, i) => buildNotification(userId, i));
      for (let i = 0; i < docs.length; i += BATCH_SIZE) {
        const chunk = docs.slice(i, i + BATCH_SIZE);
        await Notification.insertMany(chunk, { ordered: false });
      }

      insertedTotal += needed;
      touchedUsers += 1;
      console.log(`User ${userId}: existing=${existingCount}, inserted=${needed}, final=${existingCount + needed}`);
    }

    console.log(`Done. Users scanned=${users.length}, users updated=${touchedUsers}, notifications inserted=${insertedTotal}`);
  } finally {
    await Promise.allSettled([mongoose.disconnect(), mainConn.close()]);
  }
}

run().catch((error) => {
  console.error('Seeding failed:', error.message);
  process.exit(1);
});
