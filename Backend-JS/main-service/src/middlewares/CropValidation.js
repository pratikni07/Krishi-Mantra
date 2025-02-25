// middleware/validation.js
const { check, validationResult } = require("express-validator");

// Helper function for common number range validation
const numberRange = (min, max) => ({
  options: { min, max },
  errorMessage: `Value must be between ${min} and ${max}`,
});

const validation = {
  // Crop Validation Rules
  createCrop: [
    check("name")
      .trim()
      .notEmpty()
      .withMessage("Crop name is required")
      .isLength({ min: 2, max: 50 })
      .withMessage("Crop name must be between 2 and 50 characters"),

    check("scientificName")
      .trim()
      .notEmpty()
      .withMessage("Scientific name is required")
      .matches(/^[A-Za-z\s]+$/)
      .withMessage("Scientific name must contain only letters and spaces"),

    check("description")
      .optional()
      .trim()
      .isLength({ max: 1000 })
      .withMessage("Description must not exceed 1000 characters"),

    check("growingPeriod")
      .notEmpty()
      .withMessage("Growing period is required")
      .isInt(numberRange(1, 365))
      .withMessage("Growing period must be between 1 and 365 days"),

    check("seasons")
      .isArray()
      .withMessage("Seasons must be an array")
      .notEmpty()
      .withMessage("At least one season is required"),

    check("seasons.*.type")
      .notEmpty()
      .withMessage("Season type is required")
      .isIn(["Kharif", "Rabi", "Zaid"])
      .withMessage("Invalid season type"),

    check("seasons.*.startMonth")
      .notEmpty()
      .withMessage("Start month is required")
      .isInt(numberRange(1, 12))
      .withMessage("Start month must be between 1 and 12"),

    check("seasons.*.endMonth")
      .notEmpty()
      .withMessage("End month is required")
      .isInt(numberRange(1, 12))
      .withMessage("End month must be between 1 and 12"),

    check("imageUrl")
      .optional()
      .isURL()
      .withMessage("Invalid image URL format"),
  ],

  // Activity Validation Rules
  createActivity: [
    check("name")
      .trim()
      .notEmpty()
      .withMessage("Activity name is required")
      .isLength({ min: 2, max: 50 })
      .withMessage("Activity name must be between 2 and 50 characters"),

    check("description")
      .trim()
      .notEmpty()
      .withMessage("Description is required")
      .isLength({ max: 500 })
      .withMessage("Description must not exceed 500 characters"),

    check("category")
      .trim()
      .notEmpty()
      .withMessage("Category is required")
      .isIn(["Pre-planting", "Planting", "Maintenance", "Harvest"])
      .withMessage("Invalid category"),

    check("requiredTools")
      .optional()
      .isArray()
      .withMessage("Required tools must be an array"),

    check("requiredTools.*")
      .optional()
      .trim()
      .notEmpty()
      .withMessage("Tool name cannot be empty"),

    check("precautions")
      .optional()
      .isArray()
      .withMessage("Precautions must be an array"),

    check("precautions.*")
      .optional()
      .trim()
      .notEmpty()
      .withMessage("Precaution cannot be empty"),
  ],

  // Crop Calendar Validation Rules
  createCalendar: [
    check("cropId")
      .notEmpty()
      .withMessage("Crop ID is required")
      .isMongoId()
      .withMessage("Invalid Crop ID format"),

    check("month")
      .notEmpty()
      .withMessage("Month is required")
      .isInt(numberRange(1, 12))
      .withMessage("Month must be between 1 and 12"),

    check("growthStage")
      .trim()
      .notEmpty()
      .withMessage("Growth stage is required"),

    check("activities")
      .isArray()
      .withMessage("Activities must be an array")
      .notEmpty()
      .withMessage("At least one activity is required"),

    check("activities.*.activityId")
      .notEmpty()
      .withMessage("Activity ID is required")
      .isMongoId()
      .withMessage("Invalid Activity ID format"),

    check("activities.*.timing.week")
      .notEmpty()
      .withMessage("Week is required")
      .isInt(numberRange(1, 4))
      .withMessage("Week must be between 1 and 4"),

    check("activities.*.timing.recommendedTime")
      .notEmpty()
      .withMessage("Recommended time is required")
      .isIn(["Morning", "Afternoon", "Evening", "Any"])
      .withMessage("Invalid recommended time"),

    check("activities.*.importance")
      .notEmpty()
      .withMessage("Importance is required")
      .isIn(["Critical", "Important", "Optional"])
      .withMessage("Invalid importance level"),

    check("weatherConsiderations.idealTemperature.min")
      .optional()
      .isFloat(numberRange(-20, 50))
      .withMessage("Minimum temperature must be between -20°C and 50°C"),

    check("weatherConsiderations.idealTemperature.max")
      .optional()
      .isFloat(numberRange(-20, 50))
      .withMessage("Maximum temperature must be between -20°C and 50°C"),
  ],

  // Region Validation Rules
  createRegion: [
    check("name")
      .trim()
      .notEmpty()
      .withMessage("Region name is required")
      .isLength({ min: 2, max: 50 })
      .withMessage("Region name must be between 2 and 50 characters"),

    check("state").trim().notEmpty().withMessage("State is required"),

    check("country").trim().notEmpty().withMessage("Country is required"),

    check("climateType")
      .trim()
      .notEmpty()
      .withMessage("Climate type is required"),

    check("cropCalendarModifications")
      .optional()
      .isArray()
      .withMessage("Modifications must be an array"),

    check("cropCalendarModifications.*.cropCalendarId")
      .optional()
      .isMongoId()
      .withMessage("Invalid Crop Calendar ID format"),

    check("cropCalendarModifications.*.monthlyAdjustments")
      .optional()
      .isArray()
      .withMessage("Monthly adjustments must be an array"),

    check("cropCalendarModifications.*.monthlyAdjustments.*.month")
      .optional()
      .isInt(numberRange(1, 12))
      .withMessage("Month must be between 1 and 12"),
  ],

  // Search Validation Rules
  searchValidation: [
    check("search")
      .optional()
      .trim()
      .isLength({ min: 2 })
      .withMessage("Search term must be at least 2 characters"),

    check("season")
      .optional()
      .isIn(["Kharif", "Rabi", "Zaid"])
      .withMessage("Invalid season"),

    check("page")
      .optional()
      .isInt({ min: 1 })
      .withMessage("Page must be a positive integer"),

    check("limit")
      .optional()
      .isInt({ min: 1, max: 100 })
      .withMessage("Limit must be between 1 and 100"),
  ],

  // Update Validation Rules
  updateCrop: [
    check("name")
      .optional()
      .trim()
      .isLength({ min: 2, max: 50 })
      .withMessage("Crop name must be between 2 and 50 characters"),

    check("growingPeriod")
      .optional()
      .isInt(numberRange(1, 365))
      .withMessage("Growing period must be between 1 and 365 days"),

    check("seasons")
      .optional()
      .isArray()
      .withMessage("Seasons must be an array"),

    check("seasons.*.type")
      .optional()
      .isIn(["Kharif", "Rabi", "Zaid"])
      .withMessage("Invalid season type"),
  ],
};

// Middleware to handle validation
const validateRequest = (validationType) => {
  return [
    // Apply validation rules
    ...(validation[validationType] || []),

    // Check for validation errors
    (req, res, next) => {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          errors: errors.array().map((err) => ({
            field: err.param,
            message: err.msg,
          })),
        });
      }
      next();
    },
  ];
};

// Custom validation middleware for checking IDs
const validateObjectId = (req, res, next) => {
  const id = req.params.id || req.body.id;
  if (id && !mongoose.Types.ObjectId.isValid(id)) {
    return res.status(400).json({
      success: false,
      message: "Invalid ID format",
    });
  }
  next();
};

// Custom validation middleware for file uploads
const validateFileUpload = (allowedTypes) => (req, res, next) => {
  if (!req.files || Object.keys(req.files).length === 0) {
    return res.status(400).json({
      success: false,
      message: "No files were uploaded",
    });
  }

  const file = req.files.file;
  if (!allowedTypes.includes(file.mimetype)) {
    return res.status(400).json({
      success: false,
      message: "Invalid file type",
    });
  }

  next();
};

module.exports = {
  validateRequest,
  validateObjectId,
  validateFileUpload,
};
