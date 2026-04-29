const express = require("express");
const router = express.Router();
const marketplaceController = require("../controller/marketplaceController");
const { auth } = require("../middlewares/auth");

// Get all marketplace products (simplified version)
router.get("/", marketplaceController.getAllProducts);

// Search marketplace products
router.get("/search", marketplaceController.searchProducts);

// Get trending tags
router.get("/trending-tags", marketplaceController.getTrendingTags);

// List allowed product categories. Public so the mobile filter and
// add-product picker can render before the user is logged in.
router.get("/categories", marketplaceController.getCategories);

// Get a single marketplace product by ID (without comments)
router.get("/:id", marketplaceController.getProductById);

// Get comments for a product with pagination
router.get("/:id/comments", marketplaceController.getProductComments);

// Create a new marketplace product (only for marketplace admins and admins)
router.post("/", auth, marketplaceController.createProduct);

// Update a marketplace product
router.put("/:id", auth, marketplaceController.updateProduct);

// Delete a marketplace product
router.delete("/:id", auth, marketplaceController.deleteProduct);

// Add a parent comment to a marketplace product
router.post("/:id/comment", auth, marketplaceController.addComment);

// Add a reply to a comment
router.post("/:productId/comment/:commentId/reply", auth, marketplaceController.addReplyToComment);

// Update product rating
router.patch("/:id/rating", auth, marketplaceController.updateRating);

module.exports = router;
