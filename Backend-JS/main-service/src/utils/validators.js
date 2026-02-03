const Joi = require('joi');

/**
 * Common validation schemas
 */
const validators = {
  // MongoDB ObjectId validation
  objectId: Joi.string().regex(/^[0-9a-fA-F]{24}$/).messages({
    'string.pattern.base': 'Invalid ID format',
  }),

  // Phone number validation (Indian format)
  phoneNo: Joi.number()
    .integer()
    .min(1000000000)
    .max(9999999999)
    .messages({
      'number.min': 'Phone number must be 10 digits',
      'number.max': 'Phone number must be 10 digits',
    }),

  // Email validation
  email: Joi.string().email().lowercase().trim(),

  // Password validation
  password: Joi.string().min(6).max(128),

  // Pagination
  pagination: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(100).default(10),
  }),

  // Name validation
  name: Joi.string().trim().min(2).max(100),

  // OTP validation
  otp: Joi.string().length(6).pattern(/^\d+$/),
};

/**
 * Validate request body against schema
 * @param {Joi.Schema} schema - Joi schema to validate against
 * @returns {Function} - Express middleware
 */
const validate = (schema) => (req, res, next) => {
  const { error, value } = schema.validate(req.body, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const errorMessage = error.details
      .map((detail) => detail.message)
      .join(', ');
    return res.status(400).json({
      success: false,
      message: errorMessage,
    });
  }

  req.body = value;
  next();
};

/**
 * Validate query parameters against schema
 * @param {Joi.Schema} schema - Joi schema to validate against
 * @returns {Function} - Express middleware
 */
const validateQuery = (schema) => (req, res, next) => {
  const { error, value } = schema.validate(req.query, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const errorMessage = error.details
      .map((detail) => detail.message)
      .join(', ');
    return res.status(400).json({
      success: false,
      message: errorMessage,
    });
  }

  req.query = value;
  next();
};

/**
 * Validate URL parameters against schema
 * @param {Joi.Schema} schema - Joi schema to validate against
 * @returns {Function} - Express middleware
 */
const validateParams = (schema) => (req, res, next) => {
  const { error, value } = schema.validate(req.params, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const errorMessage = error.details
      .map((detail) => detail.message)
      .join(', ');
    return res.status(400).json({
      success: false,
      message: errorMessage,
    });
  }

  req.params = value;
  next();
};

// Auth schemas
const authSchemas = {
  initiateAuth: Joi.object({
    phoneNo: validators.phoneNo.required(),
  }),

  verifyOTP: Joi.object({
    phoneNo: validators.phoneNo.required(),
    otp: validators.otp.required(),
  }),

  signupWithPhone: Joi.object({
    name: validators.name.required(),
    firstName: validators.name,
    lastName: validators.name,
    phoneNo: validators.phoneNo.required(),
    image: Joi.string().uri(),
  }),

  adminLogin: Joi.object({
    email: validators.email.required(),
    password: validators.password.required(),
  }),

  changePassword: Joi.object({
    oldPassword: validators.password.required(),
    newPassword: validators.password.required(),
    confirmNewPassword: Joi.string()
      .valid(Joi.ref('newPassword'))
      .required()
      .messages({
        'any.only': 'Passwords do not match',
      }),
  }),
};

// User schemas
const userSchemas = {
  updateProfile: Joi.object({
    name: validators.name,
    firstName: validators.name,
    lastName: validators.name,
    phoneNo: validators.phoneNo,
    image: Joi.string().uri(),
  }),

  updateDetails: Joi.object({
    address: Joi.string().max(500),
    location: Joi.object({
      type: Joi.string().valid('Point'),
      coordinates: Joi.array().items(Joi.number()).length(2),
    }),
    interests: Joi.array().items(Joi.string().max(50)),
    profilePic: Joi.string().uri(),
  }),

  updateSubscription: Joi.object({
    subscriptionType: Joi.string().valid('FREE', 'PRIME', 'MEGA'),
    transactionDetails: Joi.object(),
    endDate: Joi.date(),
  }),
};

// Company schemas
const companySchemas = {
  create: Joi.object({
    name: Joi.string().trim().min(2).max(200).required(),
    logo: Joi.string().uri(),
    description: Joi.string().max(2000),
    website: Joi.string().uri(),
    contactEmail: validators.email,
    contactPhone: validators.phoneNo,
  }),

  update: Joi.object({
    name: Joi.string().trim().min(2).max(200),
    logo: Joi.string().uri(),
    description: Joi.string().max(2000),
    website: Joi.string().uri(),
    contactEmail: validators.email,
    contactPhone: validators.phoneNo,
  }),
};

// Product schemas
const productSchemas = {
  create: Joi.object({
    name: Joi.string().trim().min(2).max(200).required(),
    description: Joi.string().max(2000),
    image: Joi.string().uri(),
    companyId: validators.objectId.required(),
    usedFor: Joi.array().items(validators.objectId),
    price: Joi.number().min(0),
    category: Joi.string().max(100),
  }),

  update: Joi.object({
    name: Joi.string().trim().min(2).max(200),
    description: Joi.string().max(2000),
    image: Joi.string().uri(),
    usedFor: Joi.array().items(validators.objectId),
    price: Joi.number().min(0),
    category: Joi.string().max(100),
  }),
};

// News schemas
const newsSchemas = {
  create: Joi.object({
    content: Joi.string().min(10).max(10000).required(),
    tags: Joi.array().items(Joi.string().max(50)),
    imageUrl: Joi.string().uri(),
  }),
};

// Marketplace schemas
const marketplaceSchemas = {
  create: Joi.object({
    userId: validators.objectId.required(),
    title: Joi.string().trim().min(3).max(200).required(),
    shortDescription: Joi.string().max(500),
    detailedDescription: Joi.string().max(5000),
    priceRange: Joi.object({
      min: Joi.number().min(0).required(),
      max: Joi.number().min(Joi.ref('min')).required(),
    }),
    category: Joi.string().max(100),
    condition: Joi.string().valid('new', 'used', 'refurbished'),
    media: Joi.array().items(
      Joi.object({
        url: Joi.string().uri().required(),
        type: Joi.string().valid('image', 'video').required(),
      })
    ),
    tags: Joi.array().items(Joi.string().max(50)),
    contactNumber: validators.phoneNo,
  }),

  addComment: Joi.object({
    text: Joi.string().trim().min(1).max(1000).required(),
    userId: validators.objectId.required(),
  }),

  updateRating: Joi.object({
    rating: Joi.number().min(1).max(5).required(),
  }),
};

// Service schemas
const serviceSchemas = {
  create: Joi.object({
    title: Joi.string().trim().min(2).max(200).required(),
    image: Joi.string().uri(),
    description: Joi.string().max(2000),
    order: Joi.number().integer().min(0).default(0),
  }),

  update: Joi.object({
    title: Joi.string().trim().min(2).max(200),
    image: Joi.string().uri(),
    description: Joi.string().max(2000),
    order: Joi.number().integer().min(0),
  }),
};

// Scheme schemas
const schemeSchemas = {
  create: Joi.object({
    title: Joi.string().trim().min(2).max(200).required(),
    description: Joi.string().max(5000),
    eligibility: Joi.string().max(2000),
    benefits: Joi.string().max(2000),
    applicationProcess: Joi.string().max(2000),
    deadline: Joi.date(),
    link: Joi.string().uri(),
  }),
};

module.exports = {
  validators,
  validate,
  validateQuery,
  validateParams,
  authSchemas,
  userSchemas,
  companySchemas,
  productSchemas,
  newsSchemas,
  marketplaceSchemas,
  serviceSchemas,
  schemeSchemas,
};
