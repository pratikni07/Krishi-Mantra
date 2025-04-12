// src/routes/chat.routes.js
const express = require("express");
const router = express.Router();
const chatController = require("../controllers/chat.controller");

router.post("/direct", chatController.createDirectChat);
router.post("/list", chatController.getUserChats);
router.post("/:chatId/messages", chatController.getChatMessages);

module.exports = router;
