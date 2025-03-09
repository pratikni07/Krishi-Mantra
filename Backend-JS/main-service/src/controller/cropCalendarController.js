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
      await redis.del("all_crops");
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
      const cachedCrops = await redis.get("all_crops");
      if (cachedCrops) {
        return res.json({
          success: true,
          data: JSON.parse(cachedCrops),
        });
      }

      const crops = await Crop.find().sort({ name: 1 });
      await redis.setex("all_crops", 3600, JSON.stringify(crops)); // Cache for 1 hour
      res.json({
        success: true,
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

      const crop = await Crop.findById(req.params.id);
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

      const activities = await Activity.find().sort({ name: 1 });
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

      const cachedCalendar = await redis.get(cacheKey);
      if (cachedCalendar) {
        return res.json({
          success: true,
          data: JSON.parse(cachedCalendar),
        });
      }

      const calendar = await CropCalendar.findOne({ cropId, month })
        .populate("cropId")
        .populate("activities.activityId");

      if (!calendar) {
        return res.status(404).json({
          success: false,
          message: "Calendar not found",
        });
      }

      await redis.setex(cacheKey, 3600, JSON.stringify(calendar));
      res.json({
        success: true,
        data: calendar,
      });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
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

      const cachedMods = await redis.get(cacheKey);
      if (cachedMods) {
        return res.json({
          success: true,
          data: JSON.parse(cachedMods),
        });
      }

      const modifications = await Region.findOne(
        {
          _id: regionId,
          "cropCalendarModifications.cropCalendarId": cropId,
        },
        { "cropCalendarModifications.$": 1 }
      );

      if (!modifications) {
        return res.status(404).json({
          success: false,
          message: "Modifications not found",
        });
      }

      await redis.setex(cacheKey, 3600, JSON.stringify(modifications));
      res.json({
        success: true,
        data: modifications,
      });
    } catch (error) {
      CropCalendarController.handleErrors(res, error);
    }
  }

  // SEARCH AND FILTER OPERATIONS
  static async searchCrops(req, res) {
    try {
      const { search, season, page = 1, limit = 10 } = req.query;
      const cacheKey = `search_${search}_${season}_${page}_${limit}`;

      const cachedResults = await redis.get(cacheKey);
      if (cachedResults) {
        return res.json({
          success: true,
          data: JSON.parse(cachedResults),
        });
      }

      const query = {
        ...(search && {
          $or: [
            { name: new RegExp(search, "i") },
            { scientificName: new RegExp(search, "i") },
          ],
        }),
        ...(season && { "seasons.type": season }),
      };

      const crops = await Crop.find(query)
        .skip((page - 1) * limit)
        .limit(parseInt(limit))
        .sort({ name: 1 });

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

      await redis.setex(cacheKey, 1800, JSON.stringify(result)); // Cache for 30 minutes
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
