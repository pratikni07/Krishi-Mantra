const mongoose = require("mongoose");

const groupSchema = new mongoose.Schema(
  {
    chatId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Chat",
      required: true,
    },
    name: {
      type: String,
      required: true,
    },
    description: String,
    photo: String,
    admin: [
      {
        type: String,
        required: true,
      },
    ],
    onlyAdminCanMessage: {
      type: Boolean,
      default: false,
    },
    inviteUrl: {
      type: String,
      unique: true,
    },
    memberCount: {
      type: Number,
      default: 0,
    },
  },
  { timestamps: true }
);

groupSchema.pre("save", function (next) {
  if (this.memberCount > 400) {
    next(new Error("Group cannot have more than 400 members"));
  }
  next();
});

module.exports = mongoose.model("Group", groupSchema);
