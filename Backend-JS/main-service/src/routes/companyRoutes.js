const express = require("express");
const router = express.Router();
const companyController = require("../controller/CompanyController");

router
  .route("/")
  .post(companyController.createCompany)
  .get(companyController.getAllCompanies);

router
  .route("/:id")
  .get(companyController.getCompanyById)
  .patch(companyController.updateCompany)
  .delete(companyController.deleteCompany);

module.exports = router;
