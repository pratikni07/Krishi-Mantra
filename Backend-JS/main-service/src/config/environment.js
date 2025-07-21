const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');
const Joi = require('joi');

/**
 * Load environment variables based on NODE_ENV
 */
module.exports = function loadEnvironment() {
  const nodeEnv = process.env.NODE_ENV || 'development';
  
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
  
  // Validate critical environment variables
  validateEnvironment();
};

/**
 * Validate required environment variables
 */
function validateEnvironment() {
  const schema = Joi.object({
    NODE_ENV: Joi.string()
      .valid('development', 'production', 'test')
      .default('development'),
    PORT: Joi.number().default(3002),
    MONGODB_URL: Joi.string().required(),
    JWT_SECRET: Joi.string().required(),
    CORS_ORIGIN: Joi.string().required(),
  }).unknown(true);
  
  const { error } = schema.validate(process.env);
  
  if (error) {
    throw new Error(`Config validation error: ${error.message}`);
  }
} 