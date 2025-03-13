const Company = require("../model/Company");
const Product = require("../model/Products");

exports.createCompany = async (req, res) => {
  try {
    const company = new Company(req.body);
    await company.save();
    res.status(201).json({
      status: "success",
      data: company,
    });
  } catch (error) {
    res.status(400).json({
      status: "error",
      message: error.message,
    });
  }
};

exports.getAllCompanies = async (req, res) => {
  try {
    const companies = await Company.find().select("name logo rating");
    res.status(200).json({
      status: "success",
      results: companies.length,
      data: companies,
    });
  } catch (error) {
    res.status(500).json({
      status: "error",
      message: error.message,
    });
  }
};

exports.getCompanyById = async (req, res) => {
  try {
    const company = await Company.findById(req.params.id)
      .populate("products")
      .select("-__v");

    if (!company) {
      return res.status(404).json({
        status: "error",
        message: "Company not found",
      });
    }

    res.status(200).json({
      status: "success",
      data: company,
    });
  } catch (error) {
    res.status(500).json({
      status: "error",
      message: error.message,
    });
  }
};

exports.updateCompany = async (req, res) => {
  try {
    const company = await Company.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });

    if (!company) {
      return res.status(404).json({
        status: "error",
        message: "Company not found",
      });
    }

    res.status(200).json({
      status: "success",
      data: company,
    });
  } catch (error) {
    res.status(400).json({
      status: "error",
      message: error.message,
    });
  }
};

exports.deleteCompany = async (req, res) => {
  try {
    const company = await Company.findByIdAndDelete(req.params.id);

    if (!company) {
      return res.status(404).json({
        status: "error",
        message: "Company not found",
      });
    }

    // Remove products associated with this company
    await Product.deleteMany({ company: req.params.id });

    res.status(204).json({
      status: "success",
      data: null,
    });
  } catch (error) {
    res.status(500).json({
      status: "error",
      message: error.message,
    });
  }
};
