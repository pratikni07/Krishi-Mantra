/**
 * Async handler wrapper to eliminate try-catch blocks
 * @param {Function} fn - Express route handler
 * @returns {Function} Wrapped handler with error catching
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = asyncHandler;
module.exports.asyncHandler = asyncHandler;
