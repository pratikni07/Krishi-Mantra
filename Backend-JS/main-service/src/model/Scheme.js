const mongoose = require("mongoose");

const schemeSchema = new mongoose.Schema({
  title: { type: String, required: true },
  category: { type: String, required: true },
  description: { type: String, required: true },
  eligibility: { type: [String], required: true },
  benefits: { type: [String], required: true },
  lastDate: { type: String },
  status: { type: String, enum: ["Active", "Inactive"], required: true },
  applicationUrl: { type: String, required: true },
  documentRequired: { type: [String], required: true },
});

const Scheme = mongoose.model("Scheme", schemeSchema);

module.exports = Scheme;
