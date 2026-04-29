// controllers/cropCalendarController.js
const mongoose = require("mongoose");
const Crop = require("../model/CropCalendar/Crop");
const Activity = require("../model/CropCalendar/Activity");
const CropCalendar = require("../model/CropCalendar/CropCalendar");
const Region = require("../model/CropCalendar/Region");
const redis = require("../config/redis");
const { validationResult } = require("express-validator");

class CropCalendarController {
  // Helper function for error handling
  static handleErrors(res, error) {
    console.error("Error:", error);
    return res.status(500).json({
      success: false,
      message: "Internal server error",
      error: error.message,
    });
  }

  // CROP OPERATIONS
  static async createCrop(req, res) {
    try {
      const crop = new Crop(req.body);
      await crop.save();
      
      // Clear cache but don't fail if Redis is down
      try {
        await redis.del("all_crops");
      } catch (error) {
        console.warn("Redis error when deleting crops cache:", error.message);
      }
      
      res.status(201).json({
        success: true,
        data: crop,
      });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
  }

  static async getAllCrops(req, res) {
    try {
      // Try to get from cache but don't fail if Redis is down
      let cachedCrops = null;
      try {
        cachedCrops = await redis.get("all_crops");
      } catch (error) {
        console.warn("Redis error when getting crops:", error.message);
      }
      
      if (cachedCrops) {
        return res.json(JSON.parse(cachedCrops));
      }

      const crops = await Crop.find({ status: "active" }).sort({ name: 1 }).lean();
      
      // Cache with 1 hour expiry but don't fail if Redis is down
      try {
        await redis.setex("all_crops", 3600, JSON.stringify(crops));
      } catch (error) {
        console.warn("Redis error when setting crops cache:", error.message);
      }
      
      res.json({
        success: true,
        count: crops.length,
        data: crops,
      });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
  }

  static async getCropById(req, res) {
    try {
      const cacheKey = `crop_${req.params.id}`;
      const cachedCrop = await redis.get(cacheKey);

      if (cachedCrop) {
        return res.json({
          success: true,
          data: JSON.parse(cachedCrop),
        });
      }

      const crop = await Crop.findById(req.params.id).lean();
      if (!crop) {
        return res.status(404).json({
          success: false,
          message: "Crop not found",
        });
      }

      await redis.setex(cacheKey, 3600, JSON.stringify(crop));
      res.json({
        success: true,
        data: crop,
      });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
  }

  static async updateCrop(req, res) {
    try {
      const crop = await Crop.findByIdAndUpdate(req.params.id, req.body, {
        new: true,
        runValidators: true,
      });

      if (!crop) {
        return res.status(404).json({
          success: false,
          message: "Crop not found",
        });
      }

      await redis.del(`crop_${req.params.id}`);
      await redis.del("all_crops");

      res.json({
        success: true,
        data: crop,
      });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
  }

  static async deleteCrop(req, res) {
    try {
      const crop = await Crop.findByIdAndDelete(req.params.id);

      if (!crop) {
        return res.status(404).json({
          success: false,
          message: "Crop not found",
        });
      }

      await redis.del(`crop_${req.params.id}`);
      await redis.del("all_crops");

      res.json({
        success: true,
        message: "Crop deleted successfully",
      });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
  }

  // ACTIVITY OPERATIONS
  static async createActivity(req, res) {
    try {
      console.log(req.body);
      const activity = new Activity(req.body);
      await activity.save();
      await redis.del("all_activities");

      res.status(201).json({
        success: true,
        data: activity,
      });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
  }

  static async getAllActivities(req, res) {
    try {
      const cachedActivities = await redis.get("all_activities");
      if (cachedActivities) {
        return res.json({
          success: true,
          data: JSON.parse(cachedActivities),
        });
      }

      const activities = await Activity.find().sort({ name: 1 }).lean();
      await redis.setex("all_activities", 3600, JSON.stringify(activities));

      res.json({
        success: true,
        data: activities,
      });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
  }

  // CROP CALENDAR OPERATIONS
  static async createCropCalendar(req, res) {
    try {
      const calendar = new CropCalendar(req.body);
      await calendar.save();
      await redis.del(`calendar_${req.body.cropId}_${req.body.month}`);

      res.status(201).json({
        success: true,
        data: calendar,
      });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
  }

  static async getCropCalendar(req, res) {
    try {
      const { cropId, month } = req.params;
      const cacheKey = `calendar_${cropId}_${month}`;

      let cachedCalendar = null;
      try {
        cachedCalendar = await redis.get(cacheKey);
      } catch (e) {
        console.warn("Redis read failed for calendar:", e.message);
      }
      if (cachedCalendar) {
        return res.json({ success: true, data: JSON.parse(cachedCalendar) });
      }

      // Single-flight regeneration. Without this, a thundering herd of N
      // concurrent requests for the same calendar (all see cache miss at
      // once, e.g. right after Redis evicts the key) all hit Mongo +
      // populate two collections + write back independently. Sharing the
      // in-flight Promise collapses them into one DB hit; the rest just
      // await the result.
      const calendar = await CropCalendarController._regenCalendar(
        cropId,
        month,
        cacheKey
      );

      if (!calendar) {
        return res.status(404).json({
          success: false,
          message: "Calendar not found",
        });
      }

      res.json({ success: true, data: calendar });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
  }

  /// In-process map of in-flight regen Promises, keyed by cacheKey.
  /// Cleared as soon as the underlying Mongo query resolves so a later
  /// cache miss kicks off a fresh regeneration.
  static async _regenCalendar(cropId, month, cacheKey) {
    if (!CropCalendarController._inflight) {
      CropCalendarController._inflight = new Map();
    }
    const inflight = CropCalendarController._inflight;
    const existing = inflight.get(cacheKey);
    if (existing) return existing;

    const promise = (async () => {
      try {
        const calendar = await CropCalendar.findOne({ cropId, month })
          .populate("cropId")
          .populate("activities.activityId")
          .lean();

        if (calendar) {
          try {
            await redis.setex(cacheKey, 3600, JSON.stringify(calendar));
          } catch (e) {
            console.warn("Redis write failed for calendar:", e.message);
          }
        }
        return calendar;
      } finally {
        inflight.delete(cacheKey);
      }
    })();
    inflight.set(cacheKey, promise);
    return promise;
  }

  // REGION OPERATIONS
  static async createRegion(req, res) {
    try {
      const region = new Region(req.body);
      await region.save();
      await redis.del("all_regions");

      res.status(201).json({
        success: true,
        data: region,
      });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
  }

  static async getRegionModifications(req, res) {
    try {
      const { regionId, cropId } = req.params;
      const cacheKey = `region_mod_${regionId}_${cropId}`;

      let cachedMods = null;
      try {
        cachedMods = await redis.get(cacheKey);
      } catch (e) {
        console.warn("Redis read failed for region modifications:", e.message);
      }
      if (cachedMods) {
        return res.json({ success: true, data: JSON.parse(cachedMods) });
      }

      // Return ALL cropCalendarModifications entries that match this
      // cropId. The previous query used Mongo's positional `$` projection
      // which only ever returns the *first* matching subdocument, so a
      // region with multiple modification rows for the same crop (e.g. one
      // per growth stage) silently dropped everything past the first.
      const region = await Region.findOne(
        {
          _id: regionId,
          "cropCalendarModifications.cropCalendarId": cropId,
        },
        { cropCalendarModifications: 1 }
      ).lean();

      if (!region) {
        return res.status(404).json({
          success: false,
          message: "Modifications not found",
        });
      }

      const all = (region.cropCalendarModifications || []).filter(
        (mod) => String(mod.cropCalendarId) === String(cropId)
      );

      const payload = { regionId, cropId, modifications: all };

      try {
        await redis.setex(cacheKey, 3600, JSON.stringify(payload));
      } catch (e) {
        console.warn("Redis write failed for region modifications:", e.message);
      }

      res.json({ success: true, data: payload });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
  }

  // SEARCH AND FILTER OPERATIONS
  static async searchCrops(req, res) {
    try {
      const { search, season, page = 1, limit = 20 } = req.query;

      // Generate a unique cache key based on search parameters
      const cacheKey = `crops:search:${search || ""}:${season || ""}:${page}:${limit}`;

      // Try to get from cache but don't fail if Redis is down
      let cachedResult = null;
      try {
        cachedResult = await redis.get(cacheKey);
      } catch (error) {
        console.warn("Redis error when getting search results:", error.message);
      }

      if (cachedResult) {
        return res.json(JSON.parse(cachedResult));
      }

      // Escape regex metacharacters and cap length so user input can't
      // craft a catastrophically backtracking pattern (ReDoS) — the
      // previous version compiled `new RegExp(search, "i")` directly,
      // letting a single malicious query lock a worker for seconds.
      const safeSearch =
        typeof search === "string" && search.trim()
          ? search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").slice(0, 100)
          : null;

      // Build query based on provided parameters
      const query = {
        status: "active",
        ...(safeSearch && {
          $or: [
            { name: { $regex: safeSearch, $options: "i" } },
            { scientificName: { $regex: safeSearch, $options: "i" } },
          ],
        }),
        ...(season && { "seasons.type": season }),
      };

      const crops = await Crop.find(query)
        .skip((page - 1) * limit)
        .limit(parseInt(limit))
        .sort({ name: 1 })
        .lean();

      const total = await Crop.countDocuments(query);

      const result = {
        crops,
        pagination: {
          total,
          pages: Math.ceil(total / limit),
          currentPage: parseInt(page),
          perPage: parseInt(limit),
        },
      };

      // Cache for 30 minutes but don't fail if Redis is down
      try {
        await redis.setex(cacheKey, 1800, JSON.stringify(result));
      } catch (error) {
        console.warn("Redis error when setting search results cache:", error.message);
      }
      
      res.json({
        success: true,
        data: result,
      });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
  }
}

module.exports = CropCalendarController;
