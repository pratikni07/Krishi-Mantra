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
    email:{
      type:String,
    },
    password:{
      type:String,
    },
    phoneNo: {
      type: Number,
    },
    additionalDetails: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "UserDetail",
    },
    accountType: {
      type: String,
      enum: ["user", "consultant", "admin", "marketplace"],
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
