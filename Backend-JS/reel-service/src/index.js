// index.js
require("dotenv").config();
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const morgan = require("morgan");
const helmet = require("helmet");
const compression = require("compression");
const connectDB = require("./config/database");
const reelRoutes = require("./routes/reelRoutes");
const videoTutorialRoutes = require("./routes/videoTutorialRoutes");
const analyticsRoutes = require("./routes/analyticsRoutes");
// Import auto-reel scheduler
const autoReelScheduler = require("./utils/autoReelScheduler");

const app = express();

app.use(helmet());
app.use(cors());
app.use(compression());
app.use(morgan("dev"));
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));

connectDB()
  .then(() => {
    console.log("MongoDB Connected Successfully");

    // Start auto-reel scheduler after successful database connection
    if (process.env.ENABLE_AUTO_REELS !== "false") {
      // autoReelScheduler.init();
    }
  })
  .catch((err) => {
    console.error("Error connecting to database:", err);
  });

app.use("/reels", reelRoutes);
app.use("/videos", videoTutorialRoutes);
app.use("/analytics", analyticsRoutes);

// mongoose
//   .connect(process.env.MONGODB_URI, {
//     useNewUrlParser: true,
//     useUnifiedTopology: true,
//     serverSelectionTimeoutMS: 5000,
//   })
//   .then(() => console.log("MongoDB Connected"))
//   .catch((err) => console.error("MongoDB Connection Error:", err));

// // Handle Mongoose Connection Events
// mongoose.connection.on("connected", () => {
//   console.log("Mongoose connected to database");
// });

// mongoose.connection.on("error", (err) => {
//   console.error("Mongoose connection error:", err);
// });

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

module.exports = app;
