const express = require("express");
const router = express.Router();
const schemeController = require("../controller/schemeController");

router.post("/schemes", schemeController.createScheme);
router.get("/schemes", schemeController.getSchemes);
router.get("/schemes/:id", schemeController.getSchemeById);
router.put("/schemes/:id", schemeController.updateScheme);
router.delete("/schemes/:id", schemeController.deleteScheme);

module.exports = router;
