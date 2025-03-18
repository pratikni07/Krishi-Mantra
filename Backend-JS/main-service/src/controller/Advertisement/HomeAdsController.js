const HomeSlider = require("../../model/UIModel/HomeScreen/HomeSliderModel");
const cloudinary = require("../../config/cloudinary");
const RedisClient = require("../../config/redis");
const HomeScreenAds = require("../../model/UIModel/HomeScreen/HomeScreenAd");
const SplashModal = require("../../model/UIModel/HomeScreen/SplashModel");
const GeoLocation = require("../../model/Analytics/GeoLocation");
const axios = require("axios");

// Move the function outside the class as a standalone function
async function trackUserLocation(ip, userAgent, userId) {
  try {
    // Skip for localhost IPs
    if (ip === '127.0.0.1' || ip === '::1' || ip.includes('192.168.')) {
      // For local testing, you can use a mock location
      const mockLocation = {
        ipAddress: ip,
        country: "United States",
        region: "California",
        city: "San Francisco",
        latitude: 37.7749,
        longitude: -122.4194,
        deviceInfo: userAgent,
        userId: userId
      };
      
      await new GeoLocation(mockLocation).save();
      return;
    }
    
    // Call IP geolocation service
    const geoResponse = await axios.get(`https://ipapi.co/${ip}/json/`);
    
    if (geoResponse.data) {
      const locationData = {
        ipAddress: ip,
        country: geoResponse.data.country_name,
        region: geoResponse.data.region,
        city: geoResponse.data.city,
        latitude: geoResponse.data.latitude,
        longitude: geoResponse.data.longitude,
        deviceInfo: userAgent,
        userId: userId
      };
      
      await new GeoLocation(locationData).save();
    }
  } catch (error) {
    console.error("Error tracking location:", error);
  }
}

class HomeAdsController {
  // HOME SLIDER
  async createHomeAd(req, res) {
    try {
      const { title, content, dirURL, modal, prority } = req.body;
      // const file = req.file;

      // if (!file) {
      //   return res
      //     .status(400)
      //     .json({ error: "Missing required parameter - file" });
      // }

      // Upload file to Cloudinary
      // const cloudinaryResult = await cloudinary.uploader.upload(file.path); // Use file.path for the temp file location

      // if (!cloudinaryResult) {
      //   return res
      //     .status(500)
      //     .json({ error: "Failed to upload image to Cloudinary" });
      // }

      // Create the new Home Ad entry
      const newHomeAd = new HomeSlider({
        title,
        content,
        dirURL: dirURL,
        modal,
        prority,
      });

      await newHomeAd.save();
      await RedisClient.del("home_ads");

      res.status(201).json({ message: "Home Ad created", ad: newHomeAd });
    } catch (error) {
      console.error(error);
      res.status(500).json({ error: error.message });
    }
  }

  async getHomeAds(req, res) {
    try {
      // Track user geolocation when fetching home ads
      const ip = req.headers['x-forwarded-for'] || req.connection.remoteAddress;
      const userAgent = req.headers['user-agent'];
      const userId = req.user ? req.user._id : null;
      
      // Call the standalone function instead of a method
      trackUserLocation(ip, userAgent, userId).catch(err => 
        console.error("Error tracking location:", err)
      );
      
      const cachedAds = await RedisClient.get("home_ads");
      if (cachedAds) return res.json(JSON.parse(cachedAds));

      const ads = await HomeScreenAds.find();
      await RedisClient.setex("home_ads", 3600, JSON.stringify(ads));
      
      res.json(ads);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }

  async updateHomeAd(req, res) {
    try {
      const { id } = req.params;
      const updateData = req.body;
      const file = req.file;

      if (file) {
        const cloudinaryResult = await cloudinary.uploader.upload(file.path);
        updateData.dirURL = cloudinaryResult.secure_url;
      }

      const updatedAd = await HomeSlider.findByIdAndUpdate(id, updateData, {
        new: true,
      });
      await RedisClient.del("home_ads");

      res.json(updatedAd);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  async deleteHomeAd(req, res) {
    try {
      const { id } = req.params;
      await HomeSlider.findByIdAndDelete(id);
      await RedisClient.del("home_ads");

      res.json({ message: "Home Ad deleted successfully" });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }

  // HOME SCREEN ADS
  async createHomeScreen(req, res) {
    try {
      // if (req.file) {
      //   const uploadResult = await cloudinary.uploader.upload(req.file.path, {
      //     folder: 'home-screen-ads'
      //   });
      //   req.body.dirURL = uploadResult.secure_url;
      // }

      const document = new HomeScreenAds(req.body);
      await document.save();

      await RedisClient.set(
        `HomeScreenAds:${document._id}`,
        JSON.stringify(document)
      );

      res.status(201).json(document);
    } catch (error) {
      res.status(400).json({ message: error.message });
    }
  }

  async getHomeScreenById(req, res) {
    try {
      const cacheKey = `HomeScreenAds:${req.params.id}`;

      const cachedDocument = await RedisClient.get(cacheKey);
      if (cachedDocument) {
        return res.json(JSON.parse(cachedDocument));
      }

      const document = await HomeScreenAds.findById(req.params.id);
      if (!document) {
        return res.status(404).json({ message: "Home Screen Ad not found" });
      }

      await RedisClient.set(cacheKey, JSON.stringify(document));

      res.json(document);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }

  async updateHomeScreen(req, res) {
    try {
      // if (req.file) {
      //   const uploadResult = await cloudinary.uploader.upload(req.file.path, {
      //     folder: "home-screen-ads",
      //   });
      //   req.body.dirURL = uploadResult.secure_url;
      // }

      const document = await HomeScreenAds.findByIdAndUpdate(
        req.params.id,
        req.body,
        { new: true, runValidators: true }
      );

      if (!document) {
        return res.status(404).json({ message: "Home Screen Ad not found" });
      }

      const cacheKey = `HomeScreenAds:${document._id}`;
      await RedisClient.set(cacheKey, JSON.stringify(document));

      res.json(document);
    } catch (error) {
      res.status(400).json({ message: error.message });
    }
  }

  async deleteHomeScreen(req, res) {
    try {
      const document = await HomeScreenAds.findByIdAndDelete(req.params.id);
      if (!document) {
        return res.status(404).json({ message: "Home Screen Ad not found" });
      }

      const cacheKey = `HomeScreenAds:${req.params.id}`;
      await RedisClient.del(cacheKey);

      res.json({ message: "Home Screen Ad deleted successfully" });
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }

  async getAllHomeScreen(req, res) {
    try {
      const CACHE_KEY = "HomeScreenAds:All";

      const cachedDocuments = await RedisClient.get(CACHE_KEY);
      if (cachedDocuments) {
        return res.json(JSON.parse(cachedDocuments));
      }

      const documents = await HomeScreenAds.find();

      await RedisClient.setex(CACHE_KEY, 3600, JSON.stringify(documents));

      res.json(documents);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }

  // HOME SCREEN SPLASH MODAL
  // Create Splash Modal with Cloudinary Upload
  async createSplash(req, res) {
    try {
      // let uploadResult;
      // if (req.file) {
      //   uploadResult = await cloudinary.uploader.upload(req.file.path, {
      //     folder: "splash-modals",
      //   });
      //   req.body.dirURL = uploadResult.secure_url;
      // }

      const document = new SplashModal(req.body);
      await document.save();

      // Cache in Redis
      await RedisClient.set(
        `SplashModal:${document._id}`,
        JSON.stringify(document)
      );

      res.status(201).json(document);
    } catch (error) {
      res.status(400).json({ message: error.message });
    }
  }

  // Get Splash Modal with Redis Caching
  async getSplashById(req, res) {
    try {
      const cacheKey = `SplashModal:${req.params.id}`;

      // Check Redis cache
      const cachedDocument = await RedisClient.get(cacheKey);
      if (cachedDocument) {
        return res.json(JSON.parse(cachedDocument));
      }

      const document = await SplashModal.findById(req.params.id);
      if (!document) {
        return res.status(404).json({ message: "Splash Modal not found" });
      }

      // Cache in Redis
      await RedisClient.set(cacheKey, JSON.stringify(document));

      res.json(document);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }

  // Update Splash Modal with Cloudinary
  async updateSplash(req, res) {
    try {
      // if (req.file) {
      //   const uploadResult = await cloudinary.uploader.upload(req.file.path, {
      //     folder: "splash-modals",
      //   });
      //   req.body.dirURL = uploadResult.secure_url;
      // }

      const document = await SplashModal.findByIdAndUpdate(
        req.params.id,
        req.body,
        { new: true, runValidators: true }
      );

      if (!document) {
        return res.status(404).json({ message: "Splash Modal not found" });
      }

      // Update Redis cache
      const cacheKey = `SplashModal:${document._id}`;
      await RedisClient.set(cacheKey, JSON.stringify(document));

      res.json(document);
    } catch (error) {
      res.status(400).json({ message: error.message });
    }
  }

  // Delete Splash Modal with Cache Invalidation
  async deleteSplash(req, res) {
    try {
      const document = await SplashModal.findByIdAndDelete(req.params.id);
      if (!document) {
        return res.status(404).json({ message: "Splash Modal not found" });
      }

      // Remove from Redis cache
      const cacheKey = `SplashModal:${req.params.id}`;
      await RedisClient.del(cacheKey);

      res.json({ message: "Splash Modal deleted successfully" });
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }

  // Get All Splash Modals with Caching
  async getAllSplash(req, res) {
    try {
      const CACHE_KEY = "SplashModal:All";

      // Check Redis cache
      const cachedDocuments = await RedisClient.get(CACHE_KEY);
      if (cachedDocuments) {
        return res.json(JSON.parse(cachedDocuments));
      }

      const documents = await SplashModal.find();

      // Cache in Redis
      await RedisClient.setex(CACHE_KEY, 3600, JSON.stringify(documents));

      res.json(documents);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }
}

module.exports = new HomeAdsController();
