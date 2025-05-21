const FeedAds = require("../../model/UIModel/FeedScreen/FeedAds");
const ReelAds = require("../../model/UIModel/FeedScreen/ReelAds");
const cloudinary = require("../../config/cloudinary");
const RedisClient = require("../../config/redis");

class FeedAdsController {
  async createFeedAd(req, res) {
    try {
      const { title, content, dirURL } = req.body;
      // const file = req.file;

      // const cloudinaryResult = file
      //   ? await cloudinary.uploader.upload(file.path)
      //   : null;

      const newFeedAd = new FeedAds({
        title,
        content,
        dirURL: dirURL,
        impressions: 0,
      });

      await newFeedAd.save();

      // Clear cache but don't fail if Redis is down
      try {
        await RedisClient.del("feed_ads");
      } catch (error) {
        console.warn(
          "Redis error when clearing feed ads cache:",
          error.message
        );
      }

      res
        .status(201)
        .json({ message: "Feed Ad created successfully", ad: newFeedAd });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async getFeedAds(req, res) {
    try {
      // Try to get from cache but don't fail if Redis is down
      let cachedAds = null;
      try {
        cachedAds = await RedisClient.get("feed_ads");
      } catch (error) {
        console.warn("Redis error when getting feed ads:", error.message);
      }

      if (cachedAds) {
        return res.json(JSON.parse(cachedAds));
      }

      const feedAds = await FeedAds.find();

      // Cache for 1 hour but don't fail if Redis is down
      try {
        await RedisClient.setex("feed_ads", 3600, JSON.stringify(feedAds));
      } catch (error) {
        console.warn("Redis error when setting feed ads cache:", error.message);
      }

      res.json(feedAds);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async updateFeedAd(req, res) {
    try {
      const { id } = req.params;
      const { title, content, dirURL } = req.body;

      const updatedAd = await FeedAds.findByIdAndUpdate(
        id,
        { title, content, dirURL },
        { new: true }
      );

      if (!updatedAd) {
        return res.status(404).json({ message: "Feed Ad not found" });
      }

      // Clear cache but don't fail if Redis is down
      try {
        await RedisClient.del("feed_ads");
      } catch (error) {
        console.warn(
          "Redis error when clearing feed ads cache:",
          error.message
        );
      }

      res.json(updatedAd);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async deleteFeedAd(req, res) {
    try {
      const { id } = req.params;
      await FeedAds.findByIdAndDelete(id);

      // Clear cache but don't fail if Redis is down
      try {
        await RedisClient.del("feed_ads");
      } catch (error) {
        console.warn(
          "Redis error when clearing feed ads cache:",
          error.message
        );
      }

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
      const { title, videoUrl, popUpView } = req.body;

      const newReelAd = new ReelAds({
        title,
        videoUrl,
        popUpView: popUpView
          ? {
              enabled: true,
              productId: popUpView.productId,
              type: popUpView.type,
              image: popUpView.image,
              popupTitle: popUpView.popupTitle,
            }
          : {
              enabled: false,
            },
        impressions: 0,
        views: 0,
        viewTracking: [],
        createdAt: new Date(),
      });

      await newReelAd.save();

      // Clear cache but don't fail if Redis is down
      try {
        await RedisClient.del("reel_ads");
      } catch (error) {
        console.warn(
          "Redis error when clearing reel ads cache:",
          error.message
        );
      }

      res
        .status(201)
        .json({ message: "Reel Ad created successfully", ad: newReelAd });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async getReelAds(req, res) {
    try {
      // Try to get from cache but don't fail if Redis is down
      let cachedAds = null;
      try {
        cachedAds = await RedisClient.get("reel_ads");
      } catch (error) {
        console.warn("Redis error when getting reel ads:", error.message);
      }

      if (cachedAds) {
        return res.json(JSON.parse(cachedAds));
      }

      const reelAds = await ReelAds.find();

      // Cache for 1 hour but don't fail if Redis is down
      try {
        await RedisClient.setex("reel_ads", 3600, JSON.stringify(reelAds));
      } catch (error) {
        console.warn("Redis error when setting reel ads cache:", error.message);
      }

      res.status(200).json({ message: "Get Reel Ads", ads: reelAds });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async updateReelAd(req, res) {
    try {
      const { id } = req.params;
      const { title, videoUrl, popUpView } = req.body;

      const updateData = {
        title,
        videoUrl,
        popUpView: popUpView
          ? {
              enabled: true,
              productId: popUpView.productId,
              type: popUpView.type,
              image: popUpView.image,
              popupTitle: popUpView.popupTitle,
            }
          : {
              enabled: false,
            },
      };

      const updatedAd = await ReelAds.findByIdAndUpdate(id, updateData, {
        new: true,
      });

      if (!updatedAd) {
        return res.status(404).json({ message: "Reel Ad not found" });
      }

      // Clear cache but don't fail if Redis is down
      try {
        await RedisClient.del("reel_ads");
      } catch (error) {
        console.warn(
          "Redis error when clearing reel ads cache:",
          error.message
        );
      }

      res
        .status(200)
        .json({ message: "Reel Ad updated successfully", ad: updatedAd });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async deleteReelAd(req, res) {
    try {
      const { id } = req.params;
      await ReelAds.findByIdAndDelete(id);

      // Clear cache but don't fail if Redis is down
      try {
        await RedisClient.del("reel_ads");
      } catch (error) {
        console.warn(
          "Redis error when clearing reel ads cache:",
          error.message
        );
      }

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
        { $inc: { impression: 1 } },
        { new: true }
      );

      // Clear cache but don't fail if Redis is down
      try {
        await RedisClient.del("reel_ads");
      } catch (error) {
        console.warn(
          "Redis error when clearing reel ads cache:",
          error.message
        );
      }

      res.status(201).json({ message: "Impression tracked", ad: ad });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async trackView(req, res) {
    try {
      const { id } = req.params;
      const { userId, duration } = req.body;

      const ad = await ReelAds.findByIdAndUpdate(
        id,
        {
          $inc: { views: 1 },
          $push: {
            viewTracking: {
              userId,
              duration: duration || 0,
            },
          },
        },
        { new: true }
      );

      if (!ad) {
        return res.status(404).json({ message: "Reel Ad not found" });
      }

      // Clear cache but don't fail if Redis is down
      try {
        await RedisClient.del("reel_ads");
      } catch (error) {
        console.warn(
          "Redis error when clearing reel ads cache:",
          error.message
        );
      }

      res.status(200).json({ message: "View tracked successfully", ad });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
}

module.exports = new FeedAdsController();
