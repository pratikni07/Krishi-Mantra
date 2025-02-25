const mongoose = require("mongoose");
const testinomialSchema = new Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
  },
  testimonial: {
    type: String,
    required: true,
  },
  rating: {
    type: Number,
    required: true,
  },
  date: {
    type: Date,
    default: Date.now,
  },
  name: {
    type: String,
    required: true,
  },
  profilePhoto: {
    type: String,
  },
});

module.exports = mongoose.model("Testinomial", testinomialSchema);
