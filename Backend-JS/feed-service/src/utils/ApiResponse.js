const { HTTP_STATUS } = require('./constants');

/**
 * Standardized API Response class
 */
class ApiResponse {
  constructor(statusCode, data, message = 'Success') {
    this.success = statusCode < 400;
    this.statusCode = statusCode;
    this.message = message;
    this.data = data;
  }

  static success(data, message = 'Success') {
    return new ApiResponse(HTTP_STATUS.OK, data, message);
  }

  static created(data, message = 'Created successfully') {
    return new ApiResponse(HTTP_STATUS.CREATED, data, message);
  }

  static noContent(message = 'No content') {
    return new ApiResponse(HTTP_STATUS.NO_CONTENT, null, message);
  }

  send(res) {
    return res.status(this.statusCode).json({
      success: this.success,
      message: this.message,
      data: this.data,
    });
  }
}

module.exports = ApiResponse;
