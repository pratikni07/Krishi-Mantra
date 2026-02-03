/**
 * Migration script to initialize user interests from existing like history
 * Run this script once after deploying the recommendation feature
 *
 * Usage: node src/scripts/initializeUserInterests.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Like = require('../models/LikeModel');
const Reel = require('../models/Reel');
const ReelUserInterest = require('../models/ReelUserInterest');
const { REEL_INTEREST_CONSTANTS } = require('../models/ReelUserInterest');
const extractHashtags = require('../utils/hashtagExtractor');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/reel-service';

async function initializeUserInterests() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    console.log('Connected to MongoDB');

    // Get all unique user IDs who have liked reels
    const uniqueUsers = await Like.distinct('userId');
    console.log(`Found ${uniqueUsers.length} users with likes`);

    let processedCount = 0;
    let errorCount = 0;

    for (const userId of uniqueUsers) {
      try {
        // Find or create user interest profile
        let userInterest = await ReelUserInterest.findOne({ userId });

        if (!userInterest) {
          userInterest = new ReelUserInterest({ userId });
        }

        // Get all likes for this user
        const likes = await Like.find({ userId }).populate('reel');

        for (const like of likes) {
          if (like.reel) {
            // Extract tags from the liked reel
            let tags = like.reel.tags || [];

            // If no tags array, extract from description
            if (tags.length === 0 && like.reel.description) {
              tags = extractHashtags(like.reel.description);
            }

            // Update interests for each tag
            if (tags.length > 0) {
              userInterest.updateInterests(tags, REEL_INTEREST_CONSTANTS.INTERACTION_SCORES.like);
            }
          }
        }

        // Calculate engagement level
        userInterest.calculateEngagementLevel();
        userInterest.interactionCounts.likes = likes.length;

        await userInterest.save();
        processedCount++;

        if (processedCount % 100 === 0) {
          console.log(`Processed ${processedCount}/${uniqueUsers.length} users...`);
        }

      } catch (error) {
        console.error(`Error processing user ${userId}:`, error.message);
        errorCount++;
      }
    }

    console.log('\n=== Migration Complete ===');
    console.log(`Total users: ${uniqueUsers.length}`);
    console.log(`Successfully processed: ${processedCount}`);
    console.log(`Errors: ${errorCount}`);

  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    console.log('Disconnected from MongoDB');
    process.exit(0);
  }
}

initializeUserInterests();
