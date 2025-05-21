const cron = require("node-cron");
const axios = require("axios");
const fs = require("fs");
const path = require("path");
const logger = require("./logger");

// Import sample posts
const samplePosts = require("./samplePosts.json");
const adminConsultantUsers = require("./adminConsultantUsers.json");

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

    // Schedule the cron job to run every 2 minutes
    cron.schedule("*/2 * * * *", () => {
      this.createRandomPost()
        .then(() => logger.info("Auto post created successfully"))
        .catch((err) => logger.error("Error creating auto post:", err));
    });

    logger.info("Auto post scheduler initialized - will post every 2 minutes");
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
