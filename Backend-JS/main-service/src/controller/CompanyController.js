const Company = require('../model/Company');
const Product = require('../model/Products');
const { asyncHandler } = require('../utils');
const { HTTP_STATUS } = require('../utils/constants');

// Upper bound on the products embedded in a single company response. A
// company can have thousands of products (seed/fertilizer distributors), and
// the old `.populate('products')` without a limit shipped the entire list on
// every company detail view. Clients that need more should page through
// /companies/:id/products.
const DEFAULT_PRODUCT_PREVIEW = 20;
const MAX_PRODUCTS_PER_PAGE = 100;

/**
 * Create a new company
 */
exports.createCompany = asyncHandler(async (req, res) => {
  const company = new Company(req.body);
  await company.save();

  return res.status(HTTP_STATUS.CREATED).json({
    success: true,
    status: 'success',
    data: company,
  });
});

/**
 * Get all companies
 */
exports.getAllCompanies = asyncHandler(async (req, res) => {
  const companies = await Company.find()
    .select('name logo rating')
    .lean();

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    status: 'success',
    results: companies.length,
    data: companies,
  });
});

/**
 * Get company by ID. Returns a bounded preview of products (DEFAULT_PRODUCT_
 * PREVIEW by default) plus a productCount so the client knows whether to
 * follow up with /companies/:id/products.
 */
exports.getCompanyById = asyncHandler(async (req, res) => {
  const company = await Company.findById(req.params.id)
    .populate({
      path: 'products',
      options: { limit: DEFAULT_PRODUCT_PREVIEW, sort: { createdAt: -1 } },
    })
    .select('-__v')
    .lean();

  if (!company) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      status: 'error',
      message: 'Company not found',
    });
  }

  // Fetch raw products array length separately so we don't lose the full
  // count when the populated list is capped. The lean populate above replaces
  // company.products with the (bounded) populated docs.
  const productCount = await Product.countDocuments({ company: company._id });

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    status: 'success',
    data: {
      ...company,
      productCount,
      productsTruncated: productCount > company.products.length,
    },
  });
});

/**
 * Paginated products for a company. Use this when the preview list from
 * getCompanyById isn't enough.
 */
exports.getCompanyProducts = asyncHandler(async (req, res) => {
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const requestedLimit = parseInt(req.query.limit, 10) || DEFAULT_PRODUCT_PREVIEW;
  const limit = Math.min(Math.max(1, requestedLimit), MAX_PRODUCTS_PER_PAGE);
  const skip = (page - 1) * limit;

  const [products, total] = await Promise.all([
    Product.find({ company: req.params.id })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .select('-__v')
      .lean(),
    Product.countDocuments({ company: req.params.id }),
  ]);

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    status: 'success',
    results: products.length,
    total,
    page,
    totalPages: Math.ceil(total / limit),
    data: products,
  });
});

/**
 * Update company
 */
exports.updateCompany = asyncHandler(async (req, res) => {
  const company = await Company.findByIdAndUpdate(
    req.params.id,
    req.body,
    { new: true, runValidators: true }
  );

  if (!company) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      status: 'error',
      message: 'Company not found',
    });
  }

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    status: 'success',
    data: company,
  });
});

/**
 * Delete company
 */
exports.deleteCompany = asyncHandler(async (req, res) => {
  const company = await Company.findByIdAndDelete(req.params.id);

  if (!company) {
    return res.status(HTTP_STATUS.NOT_FOUND).json({
      success: false,
      status: 'error',
      message: 'Company not found',
    });
  }

  // Remove associated products
  await Product.deleteMany({ company: req.params.id });

  return res.status(HTTP_STATUS.OK).json({
    success: true,
    status: 'success',
    message: 'Company and associated products deleted successfully',
    data: null,
  });
});
