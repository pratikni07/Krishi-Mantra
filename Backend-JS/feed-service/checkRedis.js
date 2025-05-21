// Script to check Redis connection
require("dotenv").config();
const { checkRedisConnection } = require("./src/utils/redisCheck");

// Run the check
async function runCheck() {
  await checkRedisConnection();
  process.exit(0);
}

runCheck().catch((err) => {
  console.error("Error running Redis check:", err);
  process.exit(1);
});
