const UIDisplay = require("../../model/UIModel/UIDisplay");
const HomeSlider = require("../../model/UIModel/HomeScreen/HomeSliderModel");
const NewsAds = require("../../model/UIModel/NewsScreen/NewsAds");
const SplashModal = require("../../model/UIModel/HomeScreen/SplashModel");
const RedisClient = require("../../config/redis");

class DisplayController {
  async getDynamicDisplay(req, res) {
    try {
      // Try to get from cache but don't fail if Redis is down
      let cachedDisplay = null;
      try {
        cachedDisplay = await RedisClient.get("dynamic_display");
      } catch (error) {
        console.warn("Redis error when getting dynamic display:", error.message);
      }
      
      if (cachedDisplay) {
        return res.json(JSON.parse(cachedDisplay));
      }
      
      // If no cache or Redis is down, get from database
      const displaySettings = await UIDisplay.findOne();

      const dynamicContent = {
        displaySettings: displaySettings || {},
        homeSlider: displaySettings?.Slider
          ? await HomeSlider.find().sort({ prority: -1 })
          : [],
        splashScreen: displaySettings?.SplashScreen
          ? await SplashModal.findOne({ prority: true })
          : null,
        homeScreenAds: displaySettings?.HomeScreenAdOne
          ? await HomeSlider.findOne()
          : null,
        feedAds: displaySettings?.FeedAds ? await NewsAds.find() : [],
        reelAds: displaySettings?.ReelAds ? await NewsAds.find() : [],
        newsAds: displaySettings?.NewsAds ? await NewsAds.find() : [],
      };

      // Try to cache the result but don't fail if Redis is down
      try {
        await RedisClient.setex(
          "dynamic_display",
          3600, // 1 hour expiry
          JSON.stringify(dynamicContent)
        );
      } catch (error) {
        console.warn("Redis error when setting dynamic display:", error.message);
      }

      res.json({
        success: true,
        displaySettings,
        dynamicContent,
        message: "dynamic_display",
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  // Update Display Settings
  async updateDisplaySettings(req, res) {
    try {
      const updateData = req.body;

      // Find existing settings or create new
      let displaySettings = await UIDisplay.findOne();

      if (displaySettings) {
        displaySettings = await UIDisplay.findOneAndUpdate({}, updateData, {
          new: true,
        });
      } else {
        displaySettings = new UIDisplay(updateData);
        await displaySettings.save();
      }

      // Try to clear dynamic display cache but don't fail if Redis is down
      try {
        await RedisClient.del("dynamic_display");
      } catch (error) {
        console.warn("Redis error when deleting dynamic display cache:", error.message);
      }

      res.json(displaySettings);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
}

module.exports = new DisplayController();
