const NewsAds = require("../../model/UIModel/NewsScreen/NewsAds");
const cloudinary = require("../../config/cloudinary");
const RedisClient = require("../../config/redis");

class NewsAdsController {
  // Create News Ad
  async createNewsAd(req, res) {
    try {
      const { title, content, dirURL } = req.body;

      const newNewsAd = new NewsAds({
        title,
        content,
        dirURL: dirURL,
        impression: 0,
        views: 0,
        createdAt: new Date().toISOString(),
      });

      await newNewsAd.save();

      // Clear news ads cache
      await RedisClient.del("news_ads");

      res
        .status(201)
        .json({ message: "News Ad created successfully", ad: newNewsAd });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  // Get News Ads
  async getNewsAds(req, res) {
    try {
      // Check Redis cache first
      const cachedAds = await RedisClient.get("news_ads");
      if (cachedAds) {
        return res.json(JSON.parse(cachedAds));
      }

      const newsAds = await NewsAds.find();

      // Cache results in Redis
      await RedisClient.setex("news_ads", 3600, JSON.stringify(newsAds)); // 1 hour expiry

      res.json(newsAds);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  // Update News Ad
  async updateNewsAd(req, res) {
    try {
      const { id } = req.params;
      const updateData = req.body;

      const updatedAd = await NewsAds.findByIdAndUpdate(id, updateData, {
        new: true,
      });

      // Clear cache
      await RedisClient.del("news_ads");

      res.json(updatedAd);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  // Track Ad Impressions
  async trackImpression(req, res) {
    try {
      const { id } = req.params;
      const ad = await NewsAds.findByIdAndUpdate(
        id,
        { $inc: { impression: 1 } },
        { new: true }
      );

      // Clear cache
      await RedisClient.del("news_ads");

      res.json(ad);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  // Delete News Ad
  async deleteNewsAd(req, res) {
    try {
      const { id } = req.params;
      await NewsAds.findByIdAndDelete(id);

      await RedisClient.del("news_ads");

      res.json({ message: "News Ad deleted successfully" });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
}

module.exports = new NewsAdsController();
