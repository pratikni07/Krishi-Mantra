const express = require("express");
const router = express.Router();
const messageController = require("../controllers/message.controller");
// const authMiddleware = require("../middlewares/auth.middleware");

// router.use(authMiddleware);

router.post("/send", messageController.sendMessage);
router.put("/:messageId/read", messageController.markMessageAsRead);
router.delete("/:messageId", messageController.deleteMessage);

module.exports = router;
