const jwt = require("jsonwebtoken");
require("dotenv").config();
const User = require("../model/User");

//auth
exports.auth = async (req, res, next) => {
  try {
    //extract token
    const token =
      req.cookies.token ||
      req.body.token ||
      req.header("Authorisation").replace("Bearer ", "");
    if (!token) {
      return res.status(401).json({
        success: false,
        message: "TOken is missing",
      });
    }

    //verify the token
    try {
      const decode = jwt.verify(token, process.env.JWT_SECRET);
      // console.log("decode= ", decode);
      req.user = decode;
    } catch (err) {
      return res.status(401).json({
        success: false,
        message: "token is invalid",
      });
    }
    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: "Something went wrong while validating the token",
    });
  }
};

//isCustomer
exports.isConsultant = async (req, res, next) => {
  try {
    if (req.user.accountType !== "consultant") {
      return res.status(401).json({
        success: false,
        message: "This is a protected route for Customer only",
      });
    }
    next();
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "User role cannot be verified, please try again",
    });
  }
};

// isSeller
exports.isUser = async (req, res, next) => {
  try {
    if (req.user.accountType !== "user") {
      return res.status(401).json({
        success: false,
        message: "This is a protected route for Seller only",
      });
    }
    next();
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "User role cannot be verified, please try again",
    });
  }
};

//isAdmin
exports.isAdmin = async (req, res, next) => {
  try {
    if (req.user.accountType !== "admin") {
      return res.status(401).json({
        success: false,
        message: "This is a protected route for Admin only",
      });
    }
    next();
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "User role cannot be verified, please try again",
    });
  }
};
