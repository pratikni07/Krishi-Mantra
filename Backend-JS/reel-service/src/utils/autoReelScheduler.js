const cron = require("node-cron");
const axios = require("axios");
const fs = require("fs");
const path = require("path");
const logger = require("./logger");

// Import sample data
const sampleReels = require("./sampleReels.json");
const adminConsultantUsers = require("./adminConsultantUsers.json");

class AutoReelScheduler {
  constructor() {
    this.baseUrl = process.env.BASE_URL || "http://localhost:3000";
    this.lastReelIndex = -1;
  }

  /**
   * Initialize the auto reel scheduler
   */
  init() {
    logger.info("Starting auto reel scheduler...");
    logger.info(`Using base URL: ${this.baseUrl}`);

    // Schedule the cron job to run every 3 minutes
    // Format: '*/3 * * * *' (runs every 3 minutes)
    cron.schedule("*/3 * * * *", () => {
      this.createRandomReel()
        .then(() => logger.info("Auto reel created successfully"))
        .catch((err) => logger.error("Error creating auto reel:", err));
    });

    logger.info("Auto reel scheduler initialized - will post every 3 minutes");
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
   * Get the next reel from the sample reels JSON
   * @returns {Object} Next reel content
   */
  getNextReel() {
    this.lastReelIndex = (this.lastReelIndex + 1) % sampleReels.length;
    return sampleReels[this.lastReelIndex];
  }

  /**
   * Create a random reel using a random admin/consultant user
   */
  async createRandomReel() {
    try {
      const user = this.getRandomUser();
      const reelContent = this.getNextReel();

      // Combine user and reel data
      const reelData = {
        userId: user.userId,
        userName: user.userName,
        profilePhoto: user.profilePhoto,
        description: reelContent.description,
        mediaUrl: reelContent.mediaUrl,
        location: reelContent.location,
      };

      logger.info(`Creating reel as ${user.role} user: ${user.userName}`);
      logger.debug("Reel data to be posted:", reelData);
      logger.info(`Making POST request to: ${this.baseUrl}/reels`);

      // Make API call to create reel
      const response = await axios.post(`${this.baseUrl}/reels`, reelData, {
        headers: {
          "Content-Type": "application/json",
        },
        timeout: 10000, // 10 seconds timeout
      });

      logger.info(
        `Auto reel created successfully. Reel ID: ${response.data.data._id}`
      );
      return response.data;
    } catch (error) {
      logger.error("Error creating auto reel:", error.message);

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
        await axios.get(`${this.baseUrl}/reels/trending`);
        logger.info("Connection test successful");
      } catch (connError) {
        logger.error("Connection test failed:", connError.message);
      }

      throw error;
    }
  }
}

module.exports = new AutoReelScheduler();
