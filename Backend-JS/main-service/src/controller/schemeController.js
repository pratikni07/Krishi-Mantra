const Scheme = require("../model/Scheme");

// ✅ Create a new scheme
exports.createScheme = async (req, res) => {
  try {
    const newScheme = new Scheme(req.body);
    await newScheme.save();
    res
      .status(201)
      .json({ message: "Scheme added successfully", scheme: newScheme });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// ✅ Get all schemes
exports.getSchemes = async (req, res) => {
  try {
    const schemes = await Scheme.find();
    res.status(200).json(schemes);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// ✅ Get a scheme by ID
exports.getSchemeById = async (req, res) => {
  try {
    const scheme = await Scheme.findById(req.params.id);
    if (!scheme) {
      return res.status(404).json({ message: "Scheme not found" });
    }
    res.status(200).json(scheme);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// ✅ Update a scheme by ID
exports.updateScheme = async (req, res) => {
  try {
    const updatedScheme = await Scheme.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    if (!updatedScheme) {
      return res.status(404).json({ message: "Scheme not found" });
    }
    res
      .status(200)
      .json({ message: "Scheme updated successfully", scheme: updatedScheme });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// ✅ Delete a scheme by ID
exports.deleteScheme = async (req, res) => {
  try {
    const deletedScheme = await Scheme.findByIdAndDelete(req.params.id);
    if (!deletedScheme) {
      return res.status(404).json({ message: "Scheme not found" });
    }
    res.status(200).json({ message: "Scheme deleted successfully" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
