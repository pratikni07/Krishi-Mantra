const Joi = require('joi');
const path = require('path');
const dotenv = require('dotenv');

// Load environment variables based on NODE_ENV
const envFile = process.env.NODE_ENV === 'production'
  ? path.resolve(process.cwd(), '.env.production')
  : path.resolve(process.cwd(), '.env.development');

dotenv.config({ path: envFile });

// Environment validation schema
const envSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),
  PORT: Joi.number().default(3000),
  MONGODB_URI: Joi.string().required().description('MongoDB connection string'),
  REDIS_HOST: Joi.string().default('localhost'),
  REDIS_PORT: Joi.number().default(6379),
  REDIS_PASSWORD: Joi.string().allow('').optional(),
  ENABLE_AUTO_POST: Joi.string().valid('true', 'false').default('false'),
  RATE_LIMIT_WINDOW_MS: Joi.number().default(60000),
  RATE_LIMIT_MAX: Joi.number().default(100),
}).unknown();

// Validate environment variables
const { error, value: envVars } = envSchema.validate(process.env);

if (error) {
  console.error(`Environment validation error: ${error.message}`);
  // In development, log warning but don't exit
  if (process.env.NODE_ENV === 'production') {
    process.exit(1);
  }
}

const config = {
  env: envVars.NODE_ENV || 'development',
  port: envVars.PORT || 3000,
  mongodb: {
    uri: envVars.MONGODB_URI,
  },
  redis: {
    host: envVars.REDIS_HOST || 'localhost',
    port: envVars.REDIS_PORT || 6379,
    password: envVars.REDIS_PASSWORD,
  },
  features: {
    enableAutoPost: envVars.ENABLE_AUTO_POST === 'true',
  },
  rateLimit: {
    windowMs: envVars.RATE_LIMIT_WINDOW_MS || 60000,
    max: envVars.RATE_LIMIT_MAX || 100,
  },
};

console.log(`Environment: ${config.env}, loaded from: ${envFile}`);

module.exports = config;
