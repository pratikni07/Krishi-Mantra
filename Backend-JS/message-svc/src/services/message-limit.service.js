class MessageLimitService {
  constructor() {
    this.FREE_DAILY_LIMIT = 5;
  }

  async checkAndUpdateMessageCount(userId, incrementBy = 1) {
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
              "dailyMessageCount.count": incrementBy,
              "dailyMessageCount.lastResetDate": new Date(),
            },
          }
        );
        return {
          canSendMessage: true,
          remainingMessages: this.FREE_DAILY_LIMIT - incrementBy,
          isLimited: true,
        };
      }

      const currentCount = latestChat.dailyMessageCount.count;

      // Check if the increment would exceed limit
      if (currentCount + incrementBy > this.FREE_DAILY_LIMIT) {
        return {
          canSendMessage: false,
          remainingMessages: Math.max(0, this.FREE_DAILY_LIMIT - currentCount),
          isLimited: true,
        };
      }

      // Update count
      await AIChat.updateMany(
        { userId, "dailyMessageCount.lastResetDate": { $gte: today } },
        { $inc: { "dailyMessageCount.count": incrementBy } }
      );

      return {
        canSendMessage: true,
        remainingMessages: this.FREE_DAILY_LIMIT - (currentCount + incrementBy),
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
