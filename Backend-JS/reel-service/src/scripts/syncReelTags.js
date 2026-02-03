/**
 * Migration script to sync tags from reel descriptions to the tags array
 * Run this script once after deploying the tags field update
 *
 * Usage: node src/scripts/syncReelTags.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Reel = require('../models/Reel');
const extractHashtags = require('../utils/hashtagExtractor');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/reel-service';

async function syncReelTags() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    console.log('Connected to MongoDB');

    // Find all reels
    const reels = await Reel.find({});
    console.log(`Found ${reels.length} reels to process`);

    let updatedCount = 0;
    let skippedCount = 0;

    for (const reel of reels) {
      if (reel.description) {
        const tags = extractHashtags(reel.description);

        // Only update if there are tags to add and they're different
        if (tags.length > 0) {
          const existingTags = reel.tags || [];
          const newTags = [...new Set([...existingTags, ...tags])];

          if (JSON.stringify(existingTags.sort()) !== JSON.stringify(newTags.sort())) {
            reel.tags = newTags;
            await reel.save();
            updatedCount++;
            console.log(`Updated reel ${reel._id}: ${newTags.join(', ')}`);
          } else {
            skippedCount++;
          }
        } else {
          skippedCount++;
        }
      } else {
        skippedCount++;
      }
    }

    console.log('\n=== Migration Complete ===');
    console.log(`Total reels: ${reels.length}`);
    console.log(`Updated: ${updatedCount}`);
    console.log(`Skipped (no changes needed): ${skippedCount}`);

  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    console.log('Disconnected from MongoDB');
    process.exit(0);
  }
}

syncReelTags();
