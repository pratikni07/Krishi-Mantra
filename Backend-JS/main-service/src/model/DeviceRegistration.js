const mongoose = require('mongoose');

const DeviceRegistrationSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
      maxlength: [100, 'Name cannot exceed 100 characters'],
    },
    phone: {
      type: String,
      required: [true, 'Phone number is required'],
      validate: {
        validator: function (v) {
          return /^\d{10}$/.test(v);
        },
        message: 'Phone number must be 10 digits',
      },
    },
    email: {
      type: String,
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, 'Please provide a valid email'],
    },
    address: {
      type: String,
      required: [true, 'Address is required'],
      trim: true,
      maxlength: [500, 'Address cannot exceed 500 characters'],
    },
    deviceType: {
      type: String,
      required: [true, 'Device type is required'],
      enum: {
        values: ['auto_pump', 'krishi_doctor'],
        message: '{VALUE} is not a valid device type',
      },
    },
    status: {
      type: String,
      enum: ['pending', 'contacted', 'completed', 'cancelled'],
      default: 'pending',
    },
    adminReply: {
      message: {
        type: String,
        trim: true,
      },
      repliedAt: {
        type: Date,
      },
      repliedBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
      },
    },
    notes: {
      type: String,
      trim: true,
      maxlength: [1000, 'Notes cannot exceed 1000 characters'],
    },
    notificationSent: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

// Index for efficient querying
DeviceRegistrationSchema.index({ deviceType: 1, status: 1, createdAt: -1 });
DeviceRegistrationSchema.index({ phone: 1 });

module.exports = mongoose.model('DeviceRegistration', DeviceRegistrationSchema);
