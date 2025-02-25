// src/routes/mandiRoutes.js
import { Router } from "express";
import mandiController from "../controller/mandiController.js";

const router = Router();

router.get("/prices/state/:state", mandiController.getPricesByState);
router.get("/prices/market/:market", mandiController.getPricesByMarket);
router.get("/prices/vegetable/:vegetable", mandiController.getVegetablePrices);
router.get("/prices/latest", mandiController.getLatestPrices);

export default router;
