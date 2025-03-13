class MessageLimitService {
  constructor() {
    this.FREE_DAILY_LIMIT = 5;
  }

  async checkAndUpdateMessageCount(userId) {
    try {
      const user = await require("../models/user.model").findOne({ userId });
      if (user && user.isPremium) {
        return {
          canSendMessage: true,
          remainingMessages: null,
          isLimited: false,
        };
      }
      const AIChat = require("../models/ai-chat.model");
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      // Find the most recent chat to get the daily count
      const latestChat = await AIChat.findOne(
        { userId, "dailyMessageCount.lastResetDate": { $gte: today } },
        { dailyMessageCount: 1 }
      ).sort({ "dailyMessageCount.lastResetDate": -1 });

      if (!latestChat || latestChat.dailyMessageCount.lastResetDate < today) {
        await AIChat.updateMany(
          { userId },
          {
            $set: {
              "dailyMessageCount.count": 1,
              "dailyMessageCount.lastResetDate": new Date(),
            },
          }
        );
        return {
          canSendMessage: true,
          remainingMessages: this.FREE_DAILY_LIMIT - 1,
          isLimited: true,
        };
      }

      const currentCount = latestChat.dailyMessageCount.count;
      if (currentCount >= this.FREE_DAILY_LIMIT) {
        return {
          canSendMessage: false,
          remainingMessages: 0,
          isLimited: true,
        };
      }

      // Update count
      await AIChat.updateMany(
        { userId, "dailyMessageCount.lastResetDate": { $gte: today } },
        { $inc: { "dailyMessageCount.count": 1 } }
      );

      return {
        canSendMessage: true,
        remainingMessages: this.FREE_DAILY_LIMIT - (currentCount + 1),
        isLimited: true,
      };
    } catch (error) {
      console.error("Error checking message limits:", error);
      // Default to allowing messages if there's an error checking
      return {
        canSendMessage: true,
        remainingMessages: null,
        isLimited: false,
        error: error.message,
      };
    }
  }
}

module.exports = new MessageLimitService();
