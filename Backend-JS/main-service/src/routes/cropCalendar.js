// routes/cropCalendar.js
const express = require("express");
const router = express.Router();
const CropCalendarController = require("../controller/cropCalendarController");
const { validateRequest } = require("../middlewares/CropValidation");

// Crop routes
router.post(
  "/crops",
  validateRequest("createCrop"),
  CropCalendarController.createCrop
);
router.get("/crops", CropCalendarController.getAllCrops);
router.get("/crops/:id", CropCalendarController.getCropById);
router.put(
  "/crops/:id",
  validateRequest("updateCrop"),
  CropCalendarController.updateCrop
);
router.delete("/crops/:id", CropCalendarController.deleteCrop);

// Activity routes
router.post(
  "/activities",
  validateRequest("createActivity"),
  CropCalendarController.createActivity
);
router.get("/activities", CropCalendarController.getAllActivities);

// Calendar routes
router.post(
  "/calendar",
  validateRequest("createCalendar"),
  CropCalendarController.createCropCalendar
);
router.get("/calendar/:cropId/:month", CropCalendarController.getCropCalendar);

// Region routes
router.post(
  "/regions",
  validateRequest("createRegion"),
  CropCalendarController.createRegion
);
router.get(
  "/regions/:regionId/modifications/:cropId",
  CropCalendarController.getRegionModifications
);

// Search route
router.get("/search", CropCalendarController.searchCrops);

module.exports = router;
