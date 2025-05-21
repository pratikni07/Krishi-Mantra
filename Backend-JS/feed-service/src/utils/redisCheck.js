// Redis connection checker utility
const Redis = require("ioredis");
const redis = require("../config/redis");

/**
 * Utility to diagnose Redis connection issues
 */
async function checkRedisConnection() {
  console.log("---------------------------------------------");
  console.log("REDIS CONNECTION DIAGNOSTICS");
  console.log("---------------------------------------------");

  console.log("\n1. Checking environment variables:");
  console.log(`REDIS_HOST: ${process.env.REDIS_HOST || "localhost"}`);
  console.log(`REDIS_PORT: ${process.env.REDIS_PORT || "6379"}`);
  console.log(
    `REDIS_PASSWORD: ${
      process.env.REDIS_PASSWORD ? "(password set)" : "(no password)"
    }`
  );

  console.log("\n2. Checking current Redis client status:");
  console.log(`Using dummy client: ${redis.isDummyClient() ? "YES" : "NO"}`);

  console.log("\n3. Attempting direct Redis connection:");
  try {
    // Create a test client
    const testClient = new Redis({
      host: process.env.REDIS_HOST || "localhost",
      port: process.env.REDIS_PORT || 6379,
      password: process.env.REDIS_PASSWORD || undefined,
      connectTimeout: 5000,
    });

    // Set up event handlers for the test
    testClient.on("connect", () => {
      console.log("✓ Successfully connected to Redis server");
    });

    testClient.on("error", (err) => {
      console.error("✗ Test connection error:", err.message);
    });

    // Try a simple command
    try {
      const pingResult = await testClient.ping();
      console.log(`✓ PING command successful (response: ${pingResult})`);
      console.log("✓ Redis connection and authentication working correctly");
    } catch (cmdError) {
      console.error("✗ Command failed:", cmdError.message);

      if (cmdError.message.includes("NOAUTH")) {
        console.log("\n>> DIAGNOSIS: Redis requires authentication");
        console.log(
          ">> SOLUTION: Set a valid REDIS_PASSWORD in your .env file"
        );
      }
    }

    // Clean up
    testClient.disconnect();
  } catch (error) {
    console.error("✗ Failed to create test connection:", error.message);
  }

  console.log("\n4. Redis connection options:");
  console.log("1. Use authentic Redis with password");
  console.log("2. Use Redis without authentication");
  console.log("3. Use in-memory dummy cache (current fallback)\n");

  console.log("---------------------------------------------");
  console.log("To fix your Redis authentication issue, either:");
  console.log("1. Find the correct Redis password and set it in .env");
  console.log("2. Configure your Redis server to not require auth");
  console.log("3. Keep using the dummy client (fine for development)");
  console.log("---------------------------------------------");
}

// Export the utility
module.exports = {
  checkRedisConnection,
};
