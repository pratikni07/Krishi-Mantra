const Joi = require('joi');

const phoneNo = Joi.string()
  .pattern(/^[6-9]\d{9}$/)
  .required()
  .messages({ 'string.pattern.base': 'phoneNo must be a 10-digit Indian mobile number' });

const otp = Joi.string()
  .pattern(/^\d{4,8}$/)
  .required();

const language = Joi.string()
  .valid('hi', 'en', 'mr', 'gu', 'ta', 'te', 'kn', 'ml', 'bn', 'pa')
  .default('hi');

exports.initiateAuth = Joi.object({
  phoneNo,
  language: language.optional(),
});

exports.verifyOTP = Joi.object({
  phoneNo,
  otp,
});

exports.signupWithPhone = Joi.object({
  phoneNo,
  name: Joi.string().trim().min(1).max(100).required(),
  firstName: Joi.string().trim().max(50).optional(),
  lastName: Joi.string().trim().max(50).optional(),
  image: Joi.string().uri({ scheme: ['http', 'https'] }).max(2048).optional(),
});

exports.refreshToken = Joi.object({
  refreshToken: Joi.string().required(),
});

exports.logout = Joi.object({
  refreshToken: Joi.string().optional(),
});

exports.adminLogin = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(1).max(200).required(),
});
