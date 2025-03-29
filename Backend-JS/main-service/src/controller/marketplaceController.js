const MarketplaceProduct = require("../model/MarketplaceProduct");
const User = require("../model/User");

// Get all marketplace products (simplified version)
exports.getAllProducts = async (req, res) => {
  try {
    const products = await MarketplaceProduct.find()
      .select('title shortDescription priceRange media.url media.type sellerInfo.userName rating tags')
      .sort({ createdAt: -1 });
    
    // Filter to only include images, not videos
    const simplifiedProducts = products.map(product => {
      const imageMedia = product.media.filter(m => m.type === 'image');
      return {
        _id: product._id,
        title: product.title,
        shortDescription: product.shortDescription,
        priceRange: product.priceRange,
        images: imageMedia.map(img => img.url),
        sellerName: product.sellerInfo.userName,
        rating: product.rating,
        tags: product.tags
      };
    });
    
    res.status(200).json({
      success: true,
      count: simplifiedProducts.length,
      data: simplifiedProducts,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Get a single marketplace product by ID (without comments)
exports.getProductById = async (req, res) => {
  try {
    const product = await MarketplaceProduct.findById(req.params.id)
      .select('-comments'); // Exclude comments from the response
    
    if (!product) {
      return res.status(404).json({
        success: false,
        message: "Product not found",
      });
    }

    // Increment view count
    product.views += 1;
    await product.save();
    
    res.status(200).json({
      success: true,
      data: product,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Get comments for a product with pagination
exports.getProductComments = async (req, res) => {
  try {
    const { id } = req.params;
    const { page = 1, limit = 10 } = req.query;
    
    const product = await MarketplaceProduct.findById(id);
    
    if (!product) {
      return res.status(404).json({
        success: false,
        message: "Product not found",
      });
    }
    
    // Calculate pagination
    const startIndex = (parseInt(page) - 1) * parseInt(limit);
    const endIndex = startIndex + parseInt(limit);
    
    // Get total comments count
    const totalComments = product.comments.length;
    
    // Get paginated comments
    const paginatedComments = product.comments
      .sort((a, b) => b.createdAt - a.createdAt) // Sort by most recent
      .slice(startIndex, endIndex);
    
    // Prepare pagination info
    const pagination = {
      total: totalComments,
      pages: Math.ceil(totalComments / parseInt(limit)),
      currentPage: parseInt(page),
      hasPrevPage: parseInt(page) > 1,
      hasNextPage: endIndex < totalComments,
    };
    
    res.status(200).json({
      success: true,
      pagination,
      data: paginatedComments,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Create a new marketplace product
exports.createProduct = async (req, res) => {
  try {
    // if (req.user.accountType !== "marketplace" && req.user.accountType !== "admin") {
    //   return res.status(403).json({
    //     success: false,
    //     message: "You are not authorized to add marketplace products",
    //   });
    // }

    // Get user information
    const user = await User.findById(req.body.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    // Prepare seller info
    const sellerInfo = {
      userId: user._id,
      userName: user.name || `${user.firstName} ${user.lastName}`.trim(),
      profilePhoto: user.image || "",
      contactNumber: req.body.contactNumber || user.phoneNo,
    };

    // Construct product data
    const productData = {
      ...req.body,
      sellerInfo,
      rating: req.body.rating || 4, // Default rating is 4
    };

    const product = new MarketplaceProduct(productData);
    await product.save();
    
    res.status(201).json({
      success: true,
      data: product,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Update a marketplace product
exports.updateProduct = async (req, res) => {
  try {
    const product = await MarketplaceProduct.findById(req.params.id);
    
    if (!product) {
      return res.status(404).json({
        success: false,
        message: "Product not found",
      });
    }
    
    // Check if the user is the seller or an admin
    // if (product.sellerInfo.userId.toString() !== req.user._id.toString() && 
    //     req.user.accountType !== "admin") {
    //   return res.status(403).json({
    //     success: false,
    //     message: "You are not authorized to update this product",
    //   });
    // }
    
    const updatedProduct = await MarketplaceProduct.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );
    
    res.status(200).json({
      success: true,
      data: updatedProduct,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Delete a marketplace product
exports.deleteProduct = async (req, res) => {
  try {
    const product = await MarketplaceProduct.findById(req.params.id);
    
    if (!product) {
      return res.status(404).json({
        success: false,
        message: "Product not found",
      });
    }
    
    // Check if the user is the seller or an admin
    // if (product.sellerInfo.userId.toString() !== req.user._id.toString() && 
    //     req.user.accountType !== "admin") {
    //   return res.status(403).json({
    //     success: false,
    //     message: "You are not authorized to delete this product",
    //   });
    // }
    
    await MarketplaceProduct.findByIdAndDelete(req.params.id);
    
    res.status(200).json({
      success: true,
      message: "Product deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Add a parent comment to a marketplace product
exports.addComment = async (req, res) => {
  try {
    const { text } = req.body;
    
    if (!text) {
      return res.status(400).json({
        success: false,
        message: "Comment text is required",
      });
    }
    
    const product = await MarketplaceProduct.findById(req.params.id);
    
    if (!product) {
      return res.status(404).json({
        success: false,
        message: "Product not found",
      });
    }
    
    // Get user information
    const user = await User.findById(req.body.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }
    
    const newComment = {
      user: user._id,
      userName: user.name || `${user.firstName} ${user.lastName}`.trim(),
      userProfilePhoto: user.image || "",
      text,
      replies: []
    };
    
    product.comments.push(newComment);
    await product.save();
    
    res.status(201).json({
      success: true,
      data: newComment,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Add a reply to a comment
exports.addReplyToComment = async (req, res) => {
  try {
    const { productId, commentId } = req.params;
    const { text } = req.body;
    
    if (!text) {
      return res.status(400).json({
        success: false,
        message: "Reply text is required",
      });
    }
    
    const product = await MarketplaceProduct.findById(productId);
    
    if (!product) {
      return res.status(404).json({
        success: false,
        message: "Product not found",
      });
    }
    
    // Find the parent comment
    const parentComment = product.comments.id(commentId);
    
    if (!parentComment) {
      return res.status(404).json({
        success: false,
        message: "Comment not found",
      });
    }
    
    // Get user information
    const user = await User.findById(req.body.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }
    
    const newReply = {
      user: user._id,
      userName: user.name || `${user.firstName} ${user.lastName}`.trim(),
      userProfilePhoto: user.image || "",
      text
    };
    
    // Add reply to the parent comment
    parentComment.replies.push(newReply);
    await product.save();
    
    res.status(201).json({
      success: true,
      data: newReply,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Search marketplace products
exports.searchProducts = async (req, res) => {
  try {
    const { keyword, category, minPrice, maxPrice, condition, tags } = req.query;
    
    const query = {};
    
    if (keyword) {
      query.$or = [
        { title: { $regex: keyword, $options: 'i' } },
        { shortDescription: { $regex: keyword, $options: 'i' } },
        { detailedDescription: { $regex: keyword, $options: 'i' } }
      ];
    }
    
    if (category) {
      query.category = category;
    }
    
    if (minPrice) {
      query['priceRange.min'] = { $gte: parseInt(minPrice) };
    }
    
    if (maxPrice) {
      query['priceRange.max'] = { $lte: parseInt(maxPrice) };
    }
    
    if (condition) {
      query.condition = condition;
    }
    
    if (tags) {
      const tagArray = tags.split(',');
      query.tags = { $in: tagArray };
    }
    
    const products = await MarketplaceProduct.find(query)
      .select('title shortDescription priceRange media.url media.type sellerInfo.userName rating tags')
      .sort({ createdAt: -1 });
    
    // Filter to only include images, not videos
    const simplifiedProducts = products.map(product => {
      const imageMedia = product.media.filter(m => m.type === 'image');
      return {
        _id: product._id,
        title: product.title,
        shortDescription: product.shortDescription,
        priceRange: product.priceRange,
        images: imageMedia.map(img => img.url),
        sellerName: product.sellerInfo.userName,
        rating: product.rating,
        tags: product.tags
      };
    });
    
    res.status(200).json({
      success: true,
      count: simplifiedProducts.length,
      data: simplifiedProducts,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Get trending tags
exports.getTrendingTags = async (req, res) => {
  try {
    // Aggregate to count products by tag
    const tagCounts = await MarketplaceProduct.aggregate([
      { $unwind: "$tags" },
      { 
        $group: { 
          _id: "$tags", 
          count: { $sum: 1 },
          products: { $push: { id: "$_id", title: "$title" } }
        } 
      },
      { $sort: { count: -1 } },
      { $limit: 10 }
    ]);
    
    res.status(200).json({
      success: true,
      count: tagCounts.length,
      data: tagCounts.map(tag => ({
        tag: tag._id,
        count: tag.count,
        productSample: tag.products.slice(0, 3) // Show a few sample products for each tag
      })),
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Update product rating
exports.updateRating = async (req, res) => {
  try {
    const { rating } = req.body;
    
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: "Rating must be between 1 and 5",
      });
    }
    
    const product = await MarketplaceProduct.findById(req.params.id);
    
    if (!product) {
      return res.status(404).json({
        success: false,
        message: "Product not found",
      });
    }
    
    product.rating = rating;
    await product.save();
    
    res.status(200).json({
      success: true,
      data: {
        _id: product._id,
        rating: product.rating
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};