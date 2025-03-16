const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

function setupEnvironment() {
  const environment = process.env.NODE_ENV || 'development';
  console.log(`Starting server in ${environment} mode`);

  // Try to load environment-specific .env file
  const envFile = `.env.${environment}`;
  const envPath = path.resolve(process.cwd(), envFile);
  
  if (fs.existsSync(envPath)) {
    console.log(`Loading environment variables from ${envFile}`);
    dotenv.config({ path: envPath });
  } else {
    console.warn(`Environment file ${envFile} not found, using default .env`);
    dotenv.config();
  }
  
  // Validate required environment variables
  const requiredEnvVars = [
    'MONGODB_URL',
    'JWT_SECRET'
  ];
  
  const missingEnvVars = requiredEnvVars.filter(envVar => !process.env[envVar]);
  
  if (missingEnvVars.length > 0) {
    console.warn(`WARNING: The following required environment variables are missing: ${missingEnvVars.join(', ')}`);
    console.warn('Application may not function correctly without these variables.');
  }
}

module.exports = setupEnvironment; 