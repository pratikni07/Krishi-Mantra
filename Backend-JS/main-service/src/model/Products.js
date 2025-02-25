const mongoose = require("mongoose");

const ProductsSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    image: { type: String, required: true },
    usage: { type: String, required: true, trim: true },
    company: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Company",
    },
    usedFor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Crop",
      required: true,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Products", ProductsSchema);
