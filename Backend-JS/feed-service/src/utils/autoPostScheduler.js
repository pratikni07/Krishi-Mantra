const cron = require("node-cron");
const axios = require("axios");
const fs = require("fs");
const path = require("path");
const logger = require("./logger");
const redis = require("../config/redis");

// Import sample posts
const samplePosts = require("./samplePosts.json");
const adminConsultantUsers = require("./adminConsultantUsers.json");

// Distributed lock key + TTL. The TTL is the leader's heartbeat: if the
// leader dies mid-task, another replica can claim the slot after this
// elapses. Keep it longer than the cron interval but shorter than two
// intervals so we don't double-post when the cron fires again.
const LOCK_KEY = "feed:autopost:cron:lock";
const LOCK_TTL_SECONDS = 100; // cron is every 2 minutes (120s)

class AutoPostScheduler {
  constructor() {
    this.baseUrl = process.env.BASE_URL || "http://localhost:3033";
    this.lastPostIndex = -1;
  }

  /**
   * Initialize the auto post scheduler
   */
  init() {
    logger.info("Starting auto post scheduler...");
    logger.info(`Using base URL: ${this.baseUrl}`);

    // Schedule the cron job to run every 2 minutes. PM2 / k8s replicas
    // each get their own scheduler — without the Redis lock below, every
    // replica would post on every tick. The lock collapses the cluster
    // back to one effective poster per interval.
    cron.schedule("*/2 * * * *", () => {
      this.runWithLock()
        .then((didRun) => {
          if (didRun) logger.info("Auto post created successfully");
        })
        .catch((err) => logger.error("Error creating auto post:", err));
    });

    logger.info("Auto post scheduler initialized - will post every 2 minutes");
  }

  /**
   * Try to claim the Redis lock for this tick. If another replica already
   * holds it, no-op and return false. SET NX EX is the canonical "try
   * acquire with TTL" — atomic and survives a Redis restart cleanly.
   */
  async runWithLock() {
    try {
      const acquired = await redis.set(LOCK_KEY, process.pid, "EX", LOCK_TTL_SECONDS, "NX");
      if (!acquired) {
        logger.debug(
          "Auto post: another replica holds the lock, skipping this tick"
        );
        return false;
      }
    } catch (e) {
      // If Redis is unavailable, fall back to "best effort, possibly
      // duplicated" rather than skipping forever — better a duplicate
      // post than no posts during an outage.
      logger.warn("Auto post lock acquire failed, running unlocked:", e.message);
    }
    await this.createRandomPost();
    return true;
  }

  /**
   * Get a random user with admin or consultant role
   * @returns {Object} Random admin or consultant user
   */
  getRandomUser() {
    const randomIndex = Math.floor(Math.random() * adminConsultantUsers.length);
    return adminConsultantUsers[randomIndex];
  }

  /**
   * Get the next post from the sample posts JSON
   * @returns {Object} Next post content
   */
  getNextPost() {
    this.lastPostIndex = (this.lastPostIndex + 1) % samplePosts.length;
    return samplePosts[this.lastPostIndex];
  }

  /**
   * Create a random post using a random admin/consultant user
   */
  async createRandomPost() {
    try {
      const user = this.getRandomUser();
      const postContent = this.getNextPost();

      // Combine user and post data
      const feedData = {
        userId: user.userId,
        userName: user.userName,
        profilePhoto: user.profilePhoto,
        description: postContent.description,
        content: postContent.content,
        mediaUrl: postContent.mediaUrl,
        location: postContent.location,
      };

      logger.info(`Creating post as ${user.role} user: ${user.userName}`);
      logger.debug("Feed data to be posted:", feedData);
      logger.info(`Making POST request to: ${this.baseUrl}/feeds`);

      // Make API call to create feed
      const response = await axios.post(`${this.baseUrl}/feeds`, feedData, {
        headers: {
          "Content-Type": "application/json",
        },
        timeout: 10000, // 10 seconds timeout
      });

      logger.info(
        `Auto post created successfully. Feed ID: ${response.data._id}`
      );
      return response.data;
    } catch (error) {
      logger.error("Error creating auto post:", error.message);

      // Enhanced error logging
      if (error.response) {
        // The request was made and the server responded with a status code
        // that falls out of the range of 2xx
        logger.error("Error response details:", {
          status: error.response.status,
          statusText: error.response.statusText,
          data: error.response.data,
          headers: error.response.headers,
        });
      } else if (error.request) {
        // The request was made but no response was received
        logger.error("No response received:", error.request);
      } else {
        // Something happened in setting up the request that triggered an Error
        logger.error("Request setup error:", error.message);
      }

      // Test direct connection to server
      try {
        logger.info("Testing connection to server...");
        await axios.get(`${this.baseUrl}/feeds/getoptwo`);
        logger.info("Connection test successful");
      } catch (connError) {
        logger.error("Connection test failed:", connError.message);
      }

      throw error;
    }
  }
}

module.exports = new AutoPostScheduler();
