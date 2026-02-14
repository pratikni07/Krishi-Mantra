/**
 * Timeframe Helper
 * Converts timeframe strings to number of days
 */

/**
 * Convert timeframe string to days
 * @param {string} timeframe - Timeframe string (today, week, month, quarter, year)
 * @returns {number} Number of days
 */
function timeframeToDays(timeframe) {
  switch (timeframe) {
    case 'today':
      return 1;
    case 'week':
      return 7;
    case 'month':
      return 30;
    case 'quarter':
      return 90;
    case 'year':
      return 365;
    default:
      return 7; // Default to week
  }
}

module.exports = {
  timeframeToDays,
};
