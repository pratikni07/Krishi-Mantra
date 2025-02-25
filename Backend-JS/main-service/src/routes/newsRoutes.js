const express = require("express");
const router = express.Router();
const newsController = require("../controller/newsController");
// const { authenticateUser, authorizeRoles } = require("../middleware/auth");
// const rateLimiter = require("../middleware/rateLimiter");

// Create News (Only Admin/Moderator)
router.post(
    "/", 
    // authenticateUser, 
    // authorizeRoles('admin', 'moderator'),
    // rateLimiter({
    //     windowMs: 15 * 60 * 1000, // 15 minutes
    //     max: 5 // 5 news creation requests per window
    // }),
    newsController.createNews
);

// Get All News (Public)
router.get(
    "/", 
    // rateLimiter(),
    newsController.getAllNews
);

// Like News (Authenticated Users)
router.patch(
    "/:id/like", 
    // authenticateUser,
    // rateLimiter({
    //     windowMs: 15 * 60 * 1000, // 15 minutes
    //     max: 10 // 10 likes per window
    // }),
    newsController.likeNews
);

// Search News (Public)
router.get(
    "/search", 
    // rateLimiter(),
    newsController.searchNews
);

module.exports = router;