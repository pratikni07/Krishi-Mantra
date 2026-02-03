const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');
const Joi = require('joi');

/**
 * Environment variable schema for validation
 */
const envSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),
  PORT: Joi.number().default(3002),
  MONGODB_URL: Joi.string().required(),
  JWT_SECRET: Joi.string().min(10).required(),
  CORS_ORIGIN: Joi.string().default('http://localhost:3000'),
  REDIS_HOST: Joi.string().default('localhost'),
  REDIS_PORT: Joi.number().default(6379),
  REDIS_PASSWORD: Joi.string().allow('').default(''),
  FEED_SERVICE_URL: Joi.string().uri().default('http://localhost:3003'),
  REEL_SERVICE_URL: Joi.string().uri().default('http://localhost:3005'),
  MAIL_HOST: Joi.string(),
  MAIL_USER: Joi.string().email(),
  MAIL_PASS: Joi.string(),
  CLOUDINARY_CLOUD_NAME: Joi.string(),
  CLOUDINARY_API_KEY: Joi.string(),
  CLOUDINARY_API_SECRET: Joi.string(),
}).unknown(true);

/**
 * Load and validate environment variables
 * @returns {Object} - Validated environment configuration
 */
function setupEnvironment() {
  const environment = process.env.NODE_ENV || 'development';

  // Try to load environment-specific .env file
  const envFile = `.env.${environment}`;
  const envPath = path.resolve(process.cwd(), envFile);

  if (fs.existsSync(envPath)) {
    dotenv.config({ path: envPath });
  } else {
    // Fallback to default .env
    const defaultEnvPath = path.resolve(process.cwd(), '.env');
    if (fs.existsSync(defaultEnvPath)) {
      dotenv.config({ path: defaultEnvPath });
    }
  }

  // Validate environment variables
  const { error, value: envVars } = envSchema.validate(process.env, {
    abortEarly: false,
    allowUnknown: true,
  });

  if (error) {
    const errorMessages = error.details.map((d) => d.message).join(', ');
    console.error(`Environment validation error: ${errorMessages}`);

    // Only exit in production
    if (process.env.NODE_ENV === 'production') {
      process.exit(1);
    }
  }

  return {
    env: envVars.NODE_ENV,
    port: envVars.PORT,
    mongoUrl: envVars.MONGODB_URL,
    jwtSecret: envVars.JWT_SECRET,
    corsOrigin: envVars.CORS_ORIGIN,
    redis: {
      host: envVars.REDIS_HOST,
      port: envVars.REDIS_PORT,
      password: envVars.REDIS_PASSWORD,
    },
    services: {
      feedService: envVars.FEED_SERVICE_URL,
      reelService: envVars.REEL_SERVICE_URL,
    },
    mail: {
      host: envVars.MAIL_HOST,
      user: envVars.MAIL_USER,
      pass: envVars.MAIL_PASS,
    },
    cloudinary: {
      cloudName: envVars.CLOUDINARY_CLOUD_NAME,
      apiKey: envVars.CLOUDINARY_API_KEY,
      apiSecret: envVars.CLOUDINARY_API_SECRET,
    },
    isDevelopment: envVars.NODE_ENV === 'development',
    isProduction: envVars.NODE_ENV === 'production',
    isTest: envVars.NODE_ENV === 'test',
  };
}

module.exports = setupEnvironment;
