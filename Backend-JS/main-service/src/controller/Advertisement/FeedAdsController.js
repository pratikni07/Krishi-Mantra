const FeedAds = require("../../model/UIModel/FeedScreen/FeedAds");
const ReelAds = require("../../model/UIModel/FeedScreen/ReelAds");
const cloudinary = require("../../config/cloudinary");
const RedisClient = require("../../config/redis");

class FeedAdsController {
  async createFeedAd(req, res) {
    try {
      const { title, content, dirURL } = req.body;
      const file = req.file;

      const cloudinaryResult = file
        ? await cloudinary.uploader.upload(file.path)
        : null;

      const newFeedAd = new FeedAds({
        title,
        content,
        dirURL: cloudinaryResult ? cloudinaryResult.secure_url : dirURL,
        impressions: 0,
      });

      await newFeedAd.save();
      await RedisClient.del("feed_ads");

      res.status(201).json({ message: "Feed Ad created", ad: newFeedAd });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async getFeedAds(req, res) {
    try {
      const cachedAds = await RedisClient.get("feed_ads");
      if (cachedAds) return res.json(JSON.parse(cachedAds));

      const feedAds = await FeedAds.find();
      await RedisClient.setex("feed_ads", 3600, JSON.stringify(feedAds));
      res.status(201).json({ message: "Get Feed Ad", ad: feedAds });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async updateFeedAd(req, res) {
    try {
      const { id } = req.params;
      const updateData = req.body;
      const file = req.file;

      if (file) {
        const cloudinaryResult = await cloudinary.uploader.upload(file.path);
        updateData.dirURL = cloudinaryResult.secure_url;
      }

      const updatedAd = await FeedAds.findByIdAndUpdate(id, updateData, {
        new: true,
      });
      await RedisClient.del("feed_ads");

      res.status(201).json({ message: "updatedAd", ad: updatedAd });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async deleteFeedAd(req, res) {
    try {
      const { id } = req.params;
      await FeedAds.findByIdAndDelete(id);
      await RedisClient.del("feed_ads");

      res.json({ message: "Feed Ad deleted successfully" });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async trackImpression(req, res) {
    try {
      const { id } = req.params;
      const ad = await FeedAds.findByIdAndUpdate(
        id,
        { $inc: { impressions: 1 } },
        { new: true }
      );

      await RedisClient.del("feed_ads");
      // res.json(ad);
      res.status(201).json({ message: "track impression", ad: ad });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  // REELS CONTORLLERS
  async createReelAd(req, res) {
    try {
      const { title, content, dirURL } = req.body;
      const file = req.file;
      const cloudinaryResult = file
        ? await cloudinary.uploader.upload(file.path)
        : null;
      const newReelAd = new ReelAds({
        title,
        content,
        dirURL: cloudinaryResult ? cloudinaryResult.secure_url : dirURL,
        impressions: 0,
        views: 0,
        createdAt: new Date().toISOString(),
      });
      await newReelAd.save();
      await RedisClient.del("reel_ads");
      res.status(201).json({ message: "Reel Ad created", ad: newReelAd });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async getReelAds(req, res) {
    try {
      const cachedAds = await RedisClient.get("reel_ads");
      if (cachedAds) return res.json(JSON.parse(cachedAds));
      const reelAds = await ReelAds.find();
      await RedisClient.setex("reel_ads", 3600, JSON.stringify(reelAds));
      res.status(200).json({ message: "Get Reel Ads", ads: reelAds });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async updateReelAd(req, res) {
    try {
      const { id } = req.params;
      const updateData = req.body;
      const file = req.file;
      if (file) {
        const cloudinaryResult = await cloudinary.uploader.upload(file.path);
        updateData.dirURL = cloudinaryResult.secure_url;
      }
      const updatedAd = await ReelAds.findByIdAndUpdate(id, updateData, {
        new: true,
      });
      await RedisClient.del("reel_ads");
      res.status(200).json({ message: "Updated Reel Ad", ad: updatedAd });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async deleteReelAd(req, res) {
    try {
      const { id } = req.params;
      await ReelAds.findByIdAndDelete(id);
      await RedisClient.del("reel_ads");
      res.json({ message: "Reel Ad deleted successfully" });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async trackImpression(req, res) {
    try {
      const { id } = req.params;
      const ad = await ReelAds.findByIdAndUpdate(
        id,
        { $inc: { impressions: 1 } },
        { new: true }
      );
      await RedisClient.del("reel_ads");
      res.status(201).json({ message: "Impression tracked", ad: ad });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async trackView(req, res) {
    try {
      const { id } = req.params;
      const ad = await ReelAds.findByIdAndUpdate(
        id,
        { $inc: { views: 1 } },
        { new: true }
      );
      await RedisClient.del("reel_ads");
      res.status(201).json({ message: "View tracked", ad: ad });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
}

module.exports = new FeedAdsController();
