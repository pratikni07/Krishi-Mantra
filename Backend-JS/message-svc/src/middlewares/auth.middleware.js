const Redis = require("../config/redis");

module.exports = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(" ")[1];
    if (!token) {
      return res.status(401).json({ error: "No token provided" });
    }

    // Assuming token validation is handled by main service
    // Here we just verify if the user exists in our cache
    const userId = req.headers["x-user-id"];
    if (!userId) {
      return res.status(401).json({ error: "User ID not provided" });
    }

    const userExists = await Redis.get(`user:${userId}`);
    if (!userExists) {
      return res.status(401).json({ error: "Invalid user" });
    }

    req.user = { userId };
    next();
  } catch (error) {
    console.error("Auth middleware error:", error);
    return res.status(500).json({ error: "Internal server error" });
  }
};
