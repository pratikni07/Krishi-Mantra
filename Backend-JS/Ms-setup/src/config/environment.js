/**
 * Shared environment configuration module for all microservices
 */

const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');
const Joi = require('joi');

/**
 * Load environment variables based on NODE_ENV
 * @param {Object} options Configuration options
 * @param {string} options.serviceName Name of the service (for logging)
 * @param {Function} options.validator Custom schema validator function
 * @returns {Object} Validated environment variables
 */
function loadEnvironment(options = {}) {
  const { serviceName = 'microservice', validator } = options;
  const nodeEnv = process.env.NODE_ENV || 'development';
  
  console.log(`Starting ${serviceName} in ${nodeEnv} environment`);
  
  // Determine which env file to load
  let envFile;
  if (nodeEnv === 'production') {
    envFile = path.resolve(process.cwd(), '.env.production');
  } else if (nodeEnv === 'test') {
    envFile = path.resolve(process.cwd(), '.env.test');
  } else {
    envFile = path.resolve(process.cwd(), '.env.development');
  }
  
  // Check if file exists, if not, fall back to .env
  if (!fs.existsSync(envFile)) {
    envFile = path.resolve(process.cwd(), '.env');
    console.warn(`${nodeEnv} environment file not found, falling back to .env`);
  }
  
  // Load environment variables from file
  const result = dotenv.config({ path: envFile });
  
  if (result.error) {
    throw new Error(`Error loading environment from ${envFile}: ${result.error.message}`);
  }
  
  console.log(`Loaded environment from ${envFile} for ${nodeEnv} mode`);
  
  // Validate environment variables
  let validatedEnv;
  try {
    validatedEnv = validateEnvironment(validator);
  } catch (error) {
    console.error(`Environment validation error: ${error.message}`);
    process.exit(1);
  }
  
  return validatedEnv;
}

/**
 * Validate environment variables using Joi
 * @param {Function} customValidator Custom validation schema function
 * @returns {Object} Validated environment variables
 */
function validateEnvironment(customValidator) {
  // Base schema all services should have
  const baseSchema = Joi.object({
    NODE_ENV: Joi.string()
      .valid('development', 'production', 'test')
      .default('development'),
    PORT: Joi.number().default(3000),
    MONGODB_URL: Joi.string().required(),
    MONGODB_URI: Joi.string(), // Some services use URI instead of URL
    JWT_SECRET: Joi.string().required(),
    CORS_ORIGIN: Joi.string().required(),
    REDIS_HOST: Joi.string().default('localhost'),
    REDIS_PORT: Joi.number().default(6379),
    REDIS_PASSWORD: Joi.string().allow(''),
    LOG_LEVEL: Joi.string().valid('error', 'warn', 'info', 'http', 'debug').default('info'),
  }).unknown(true);
  
  // If custom validator is provided, combine with base schema
  const schema = customValidator ? customValidator(baseSchema) : baseSchema;
  
  const { error, value } = schema.validate(process.env);
  
  if (error) {
    throw new Error(`Config validation error: ${error.message}`);
  }
  
  return value;
}

/**
 * Create environment-specific configuration for a service
 * @param {Object} options Configuration options
 * @returns {Object} Environment configuration
 */
function createConfig(options = {}) {
  const env = loadEnvironment(options);
  
  // Common configuration across all environments
  const config = {
    env: env.NODE_ENV,
    port: env.PORT,
    mongodb: {
      url: env.MONGODB_URL || env.MONGODB_URI,
      options: {
        useNewUrlParser: true,
        useUnifiedTopology: true,
      },
    },
    jwt: {
      secret: env.JWT_SECRET,
      expiresIn: env.JWT_EXPIRY || '24h',
      refreshExpiresIn: env.REFRESH_TOKEN_EXPIRY || '30d',
    },
    cors: {
      origin: env.CORS_ORIGIN.split(','),
      credentials: true,
    },
    redis: {
      host: env.REDIS_HOST,
      port: env.REDIS_PORT,
      password: env.REDIS_PASSWORD,
      ssl: env.REDIS_SSL === 'true',
    },
    logger: {
      level: env.LOG_LEVEL,
    },
    services: {
      main: env.MAIN_SERVICE_URL || 'http://localhost:3002',
      messages: env.MESSAGE_SERVICE_URL || 'http://localhost:3004',
      feed: env.FEED_SERVICE_URL || 'http://localhost:3003',
      notification: env.NOTIFICATION_SERVICE_URL || 'http://localhost:3006',
      reel: env.REEL_SERVICE_URL || 'http://localhost:3005',
      gateway: env.API_GATEWAY_URL || 'http://localhost:3001',
    },
  };
  
  // Environment-specific overrides
  if (config.env === 'development') {
    // Development-specific settings
    config.isDev = true;
  } else if (config.env === 'production') {
    // Production-specific settings
    config.isProd = true;
    config.mongodb.options.maxPoolSize = 50;
  }
  
  return config;
}

module.exports = {
  loadEnvironment,
  validateEnvironment,
  createConfig,
}; 