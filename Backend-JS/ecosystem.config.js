module.exports = {
  apps: [
    {
      name: 'api-gateway',
      cwd: './api-gateway-service',
      script: 'index.js',
      env: {
        NODE_ENV: 'development',
        PORT: 3001
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3001
      },
      watch: false,
      instances: 1,
      autorestart: true,
      max_memory_restart: '500M'
    },
    {
      name: 'main-service',
      cwd: './main-service',
      script: 'src/index.js',
      env: {
        NODE_ENV: 'development',
        PORT: 3002
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3002
      },
      watch: false,
      instances: 1,
      autorestart: true,
      max_memory_restart: '500M'
    },
    {
      name: 'feed-service',
      cwd: './feed-service',
      script: 'src/index.js',
      env: {
        NODE_ENV: 'development',
        PORT: 3003
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3003
      },
      watch: false,
      instances: 1,
      autorestart: true,
      max_memory_restart: '500M'
    },
    {
      name: 'message-service',
      cwd: './message-svc',
      script: 'src/index.js',
      env: {
        NODE_ENV: 'development',
        PORT: 3004
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3004
      },
      watch: false,
      instances: 1,
      autorestart: true,
      max_memory_restart: '500M'
    },
    {
      name: 'reel-service',
      cwd: './reel-service',
      script: 'src/index.js',
      env: {
        NODE_ENV: 'development',
        PORT: 3005
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3005
      },
      watch: false,
      instances: 1,
      autorestart: true,
      max_memory_restart: '500M'
    },
    {
      name: 'notification-service',
      cwd: './notification-service',
      script: 'src/server.js',
      env: {
        NODE_ENV: 'development',
        PORT: 3006
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3006
      },
      watch: false,
      instances: 1,
      autorestart: true,
      max_memory_restart: '500M'
    },
    {
      name: 'engagement-service',
      cwd: './engagement-service',
      script: 'src/index.js',
      env: {
        NODE_ENV: 'development',
        PORT: 3007
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3007
      },
      watch: false,
      instances: 1,
      autorestart: true,
      max_memory_restart: '1G'
    }
  ]
};
