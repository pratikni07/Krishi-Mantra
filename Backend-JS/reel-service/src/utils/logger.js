const fs = require("fs");
const path = require("path");

// Create logs directory if it doesn't exist
const logsDir = path.join(__dirname, "../../logs");
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

// Log file paths
const logFilePath = path.join(logsDir, "auto-reel.log");
const errorLogFilePath = path.join(logsDir, "auto-reel-error.log");

/**
 * Simple logging utility
 */
class Logger {
  /**
   * Format log message with timestamp
   * @param {string} level - Log level
   * @param {string} message - Log message
   * @param {Object} [data] - Additional data to log
   * @returns {string} Formatted log message
   */
  formatLogMessage(level, message, data = null) {
    const timestamp = new Date().toISOString();
    let logMsg = `[${timestamp}] [${level}] ${message}`;

    if (data) {
      if (typeof data === "object") {
        logMsg += `\n${JSON.stringify(data, null, 2)}`;
      } else {
        logMsg += ` ${data}`;
      }
    }

    return logMsg;
  }

  /**
   * Write to log file and console
   * @param {string} level - Log level
   * @param {string} message - Log message
   * @param {Object} [data] - Additional data to log
   */
  log(level, message, data = null) {
    const logMsg = this.formatLogMessage(level, message, data);

    // Write to console
    if (level === "ERROR") {
      console.error(logMsg);
    } else {
      console.log(logMsg);
    }

    // Write to file
    const filePath = level === "ERROR" ? errorLogFilePath : logFilePath;
    fs.appendFileSync(filePath, logMsg + "\n");
  }

  /**
   * Log info message
   * @param {string} message - Log message
   * @param {Object} [data] - Additional data to log
   */
  info(message, data = null) {
    this.log("INFO", message, data);
  }

  /**
   * Log error message
   * @param {string} message - Log message
   * @param {Object|Error} [error] - Error object or additional data
   */
  error(message, error = null) {
    let errorData = null;

    if (error instanceof Error) {
      errorData = {
        message: error.message,
        stack: error.stack,
      };
    } else {
      errorData = error;
    }

    this.log("ERROR", message, errorData);
  }

  /**
   * Log warning message
   * @param {string} message - Log message
   * @param {Object} [data] - Additional data to log
   */
  warn(message, data = null) {
    this.log("WARN", message, data);
  }

  /**
   * Log debug message
   * @param {string} message - Log message
   * @param {Object} [data] - Additional data to log
   */
  debug(message, data = null) {
    if (process.env.NODE_ENV !== "production") {
      this.log("DEBUG", message, data);
    }
  }
}

module.exports = new Logger();
