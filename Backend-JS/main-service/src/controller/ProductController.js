const Product = require('../model/Products');
const Company = require('../model/Company');
const { asyncHandler } = require('../utils');
const { HTTP_STATUS } = require('../utils/constants');

/**
 * Create a new product
 */
exports.createProduct = asyncHandler(async (req, res) => {
  const { companyId, ...productData } = req.body;

  // Create product
  const product = new Product({
    ...productData,
    company: companyId,
  });
  await product.save();

  // Add product to company's products array
  if (companyId) {
    await Company.findByIdAndUpdate(
      companyId,
      { $push: { products: product._id } },
      { new: true }
    );
  }

  return res.status(HTTP_STATUS.CREATED).json({
    success: true,
    status: 'success',
    data: product,
  });
});

/**
 * Get all products
 */
exports.getAllProducts = asyncHandler(async (req, res) => {
  const products = await Product.find()
    .populate('company', 'name logo')
    .populate('usedFor', 'name imageUrl')
    .select('-__v')
    .lean();

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    status: 'success',
    results: products.length,
    data: products,
  });
});

/**
 * Get product by ID
 */
exports.getProductById = asyncHandler(async (req, res) => {
  const product = await Product.findById(req.params.id)
    .populate('company', 'name logo')
    .populate('usedFor', 'name imageUrl')
    .select('-__v')
    .lean();

  if (!product) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      status: 'error',
      message: 'Product not found',
    });
  }

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    status: 'success',
    data: product,
  });
});

/**
 * Update product
 */
exports.updateProduct = asyncHandler(async (req, res) => {
  const product = await Product.findByIdAndUpdate(
    req.params.id,
    req.body,
    { new: true, runValidators: true }
  );

  if (!product) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      status: 'error',
      message: 'Product not found',
    });
  }

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    status: 'success',
    data: product,
  });
});

/**
 * Delete product
 */
exports.deleteProduct = asyncHandler(async (req, res) => {
  const product = await Product.findByIdAndDelete(req.params.id);

  if (!product) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      status: 'error',
      message: 'Product not found',
    });
  }

  // Remove product reference from company
  if (product.company) {
    await Company.findByIdAndUpdate(product.company, {
      $pull: { products: product._id },
    });
  }

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    status: 'success',
    message: 'Product deleted successfully',
    data: null,
  });
});
