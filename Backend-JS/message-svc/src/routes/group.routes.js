const express = require("express");
const router = express.Router();
const groupController = require("../controllers/group.controller");
// const authMiddleware = require("../middlewares/auth.middleware");

// router.use(authMiddleware);

router.post("/create", groupController.createGroup);
router.post("/:groupId/participants", groupController.addGroupParticipants);
router.post("/join/:inviteUrl", groupController.joinGroupViaInvite);
router.put("/:groupId/settings", groupController.updateGroupSettings);

module.exports = router;
