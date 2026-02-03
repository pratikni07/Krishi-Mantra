const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
      maxlength: [100, 'Name cannot exceed 100 characters'],
    },
    firstName: {
      type: String,
      trim: true,
      maxlength: [50, 'First name cannot exceed 50 characters'],
    },
    lastName: {
      type: String,
      trim: true,
      maxlength: [50, 'Last name cannot exceed 50 characters'],
    },
    email: {
      type: String,
      lowercase: true,
      trim: true,
      sparse: true,
      match: [/^\S+@\S+\.\S+$/, 'Please provide a valid email'],
    },
    password: {
      type: String,
      select: false,
    },
    phoneNo: {
      type: Number,
      validate: {
        validator: function (v) {
          return v === undefined || v === null || /^\d{10}$/.test(v.toString());
        },
        message: 'Phone number must be 10 digits',
      },
    },
    additionalDetails: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'UserDetail',
    },
    accountType: {
      type: String,
      enum: {
        values: ['user', 'consultant', 'admin', 'marketplace'],
        message: '{VALUE} is not a valid account type',
      },
      default: 'user',
    },
    token: {
      type: String,
      select: false,
    },
    image: {
      type: String,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes for better query performance
UserSchema.index({ email: 1 }, { sparse: true });
UserSchema.index({ phoneNo: 1 }, { sparse: true });
UserSchema.index({ accountType: 1 });
UserSchema.index({ name: 'text' });
UserSchema.index({ createdAt: -1 });

// Virtual for full name
UserSchema.virtual('fullName').get(function () {
  if (this.firstName && this.lastName) {
    return `${this.firstName} ${this.lastName}`;
  }
  return this.name;
});

// Ensure virtuals are included in JSON output
UserSchema.set('toJSON', { virtuals: true });
UserSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('User', UserSchema);
