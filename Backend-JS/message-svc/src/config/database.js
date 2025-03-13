const mongoose = require("mongoose");

class Database {
  constructor() {
    this.mongoURI =
      process.env.MONGODB_URI || "mongodb://localhost:27017/farmer-chat";
  }

  async connect() {
    try {
      const options = {
        useNewUrlParser: true,
        useUnifiedTopology: true,
        serverSelectionTimeoutMS: 5000,
      };

      await mongoose.connect(this.mongoURI, options);

      mongoose.connection.on("connected", () => {
        console.log("MongoDB connected successfully");
      });

      mongoose.connection.on("error", (err) => {
        console.error("MongoDB connection error:", err);
      });

      mongoose.connection.on("disconnected", () => {
        console.log("MongoDB disconnected");
      });

      // Graceful shutdown
      process.on("SIGINT", async () => {
        try {
          await mongoose.connection.close();
          console.log("MongoDB connection closed through app termination");
          process.exit(0);
        } catch (err) {
          console.error("Error during MongoDB disconnect:", err);
          process.exit(1);
        }
      });
    } catch (error) {
      console.error("MongoDB connection error:", error);
      process.exit(1);
    }
  }
}

module.exports = new Database();
