const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const path = require('path');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config({ path: path.join(__dirname, '../../.env.development') });
dotenv.config({ path: path.join(__dirname, '../../.env') });

const User = require('../model/User');

async function createMarketplaceAdmin() {
  try {
    // Connect to MongoDB
    const mongoUri = process.env.MONGODB_URL || process.env.MONGODB_URI || process.env.MONGO_URI;
    console.log('Connecting to MongoDB...');
    console.log('URI:', mongoUri ? 'Found' : 'Not found');
    await mongoose.connect(mongoUri);
    console.log('Connected to MongoDB');

    const email = 'marketplace@gmail.com';
    const password = '#P123n1234';
    const accountType = 'marketplace';

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      console.log('User already exists with this email');
      console.log('Updating user...');

      // Update existing user
      const hashedPassword = await bcrypt.hash(password, 10);
      await User.findByIdAndUpdate(existingUser._id, {
        password: hashedPassword,
        accountType: accountType,
        isActive: true,
      });

      console.log('User updated successfully!');
      console.log('Email:', email);
      console.log('Password:', password);
      console.log('Account Type:', accountType);
    } else {
      // Create new user
      const hashedPassword = await bcrypt.hash(password, 10);

      const newUser = await User.create({
        name: 'Marketplace Admin',
        email: email,
        password: hashedPassword,
        accountType: accountType,
        isActive: true,
        image: 'https://api.dicebear.com/6.x/initials/png?seed=MA&backgroundColor=00897b',
      });

      console.log('Marketplace admin created successfully!');
      console.log('User ID:', newUser._id);
      console.log('Email:', email);
      console.log('Password:', password);
      console.log('Account Type:', accountType);
    }

    await mongoose.disconnect();
    console.log('Disconnected from MongoDB');
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

createMarketplaceAdmin();
