const Company = require('../model/Company');
const Product = require('../model/Products');
const { asyncHandler } = require('../utils');
const { HTTP_STATUS } = require('../utils/constants');

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
 * Get company by ID
 */
exports.getCompanyById = asyncHandler(async (req, res) => {
  const company = await Company.findById(req.params.id)
    .populate('products')
    .select('-__v')
    .lean();

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
