module.exports = {
  apps: [
    {
      name: "krishi-app",
      script: "src/index.js",
      instances: "max",
      exec_mode: "cluster",
      autorestart: true,
      watch: false,
      max_memory_restart: "1G",
      env_production: {
        NODE_ENV: "production",
        PORT: 3002
      },
      env_development: {
        NODE_ENV: "development",
        PORT: 3002
      }
    }
  ]
}; 