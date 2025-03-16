const mongoose = require("mongoose");

require("dotenv").config();

const connect = () => {
  mongoose
    .connect(process.env.MONGODB_URL, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      // // Connection pooling settings
      // maxPoolSize: 10, // Maintain up to 10 socket connections
      // minPoolSize: 5,  // Maintain at least 5 socket connections
      // socketTimeoutMS: 45000, // Close sockets after 45 seconds of inactivity
      // // Handle retries automatically
      // serverSelectionTimeoutMS: 5000, // Keep trying to send operations for 5 seconds
      // retryWrites: true,
      // // Log slow queries (over 100ms)
      // slowTime: 100
    })
    .then(() => console.log("DB Connected Successfully"))
    .catch((error) => {
      console.log("DB Connection Failed");
      console.error(error);
      process.exit(1);
    });
    
    // Handle connection events
    mongoose.connection.on('error', err => {
      console.error('MongoDB connection error:', err);
    });
    
    mongoose.connection.on('disconnected', () => {
      console.warn('MongoDB disconnected. Attempting to reconnect...');
    });
    
    mongoose.connection.on('reconnected', () => {
      console.info('MongoDB reconnected successfully');
    });
    
    // Graceful shutdown
    process.on('SIGINT', async () => {
      try {
        await mongoose.connection.close();
        console.log('MongoDB connection closed due to app termination');
        process.exit(0);
      } catch (err) {
        console.error('Error during MongoDB connection closure:', err);
        process.exit(1);
      }
    });
};

module.exports = connect;