const express = require("express");
const router = express.Router();
const marketplaceController = require("../controller/marketplaceController");

// Get all marketplace products (simplified version)
router.get("/", marketplaceController.getAllProducts);

// Search marketplace products
router.get("/search", marketplaceController.searchProducts);

// Get trending tags
router.get("/trending-tags", marketplaceController.getTrendingTags);

// Get a single marketplace product by ID (without comments)
router.get("/:id", marketplaceController.getProductById);

// Get comments for a product with pagination
router.get("/:id/comments", marketplaceController.getProductComments);

// Create a new marketplace product (only for marketplace admins and admins)
router.post("/",  marketplaceController.createProduct);

// Update a marketplace product
router.put("/:id",  marketplaceController.updateProduct);

// Delete a marketplace product
router.delete("/:id",  marketplaceController.deleteProduct);

// Add a parent comment to a marketplace product
router.post("/:id/comment",  marketplaceController.addComment);

// Add a reply to a comment
router.post("/:productId/comment/:commentId/reply",  marketplaceController.addReplyToComment);

// Update product rating
router.patch("/:id/rating",  marketplaceController.updateRating);

module.exports = router; 