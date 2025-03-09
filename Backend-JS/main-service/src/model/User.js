const mongoose = require("mongoose");

const UserSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "Name is required"],
      trim: true,
    },
    firstName: {
      type: String,
      trim: true,
    },
    lastName: {
      type: String,
      trim: true,
    },
    // email: {
    //   type: String,
    //   required: [true, "Email is required"],
    //   unique: true,
    //   lowercase: true,
    //   trim: true,
    //   match: [
    //     /^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/,
    //     "Please fill a valid email address",
    //   ],
    // },
    // password: {
    //   type: String,
    //   required: [true, "Password is required"],
    //   minlength: [8, "Password must be at least 8 characters long"],
    // },
    phoneNo: {
      type: Number,
    },
    additionalDetails: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserDetail",
    },
    accountType: {
      type: String,
      enum: ["user", "consultant", "admin"],
      default: "user",
    },
    token: {
      type: String,
    },
    image: {
      type: String,
    },
    createdAt: {
      type: Date,
      default: Date.now,
    },
    // interest:[
    //   {
    //     type:mongoose.Schema.Types.ObjectId,
    //     ref:'Tags'
    //   }
    // ]
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("User", UserSchema);
