const Group = require("../models/group.model");
const Chat = require("../models/chat.model");
const { v4: uuidv4 } = require("uuid");

class GroupController {
  async createGroup(req, res) {
    try {
      const {
        userId,
        userName,
        profilePhoto,
        name,
        description,
        participants,
        onlyAdminCanMessage,
      } = req.body;

      if (participants.length > 399) {
        return res
          .status(400)
          .json({ error: "Group cannot have more than 400 members" });
      }

      const chat = await Chat.create({
        type: "group",
        participants: [
          ...participants,
          {
            userId,
            userName,
            profilePhoto,
          },
        ],
      });

      const group = await Group.create({
        chatId: chat._id,
        name,
        description,
        admin: [userId],
        onlyAdminCanMessage,
        inviteUrl: uuidv4(),
        memberCount: participants.length + 1,
      });

      return res.status(201).json({ chat, group });
    } catch (error) {
      console.error("Create group error:", error);
      return res.status(500).json({ error: "Internal server error" });
    }
  }

  async addGroupParticipants(req, res) {
    try {
      const { groupId } = req.params;
      const { userId, participants } = req.body;

      const group = await Group.findById(groupId);
      if (!group) {
        return res.status(404).json({ error: "Group not found" });
      }

      if (!group.admin.includes(userId)) {
        return res
          .status(403)
          .json({ error: "Only admins can add participants" });
      }

      if (group.memberCount + participants.length > 400) {
        return res
          .status(400)
          .json({ error: "Group cannot have more than 400 members" });
      }

      const chat = await Chat.findById(group.chatId);

      // Validate that each participant has required fields
      const validatedParticipants = participants.map((p) => ({
        userId: p.userId,
        userName: p.userName,
        profilePhoto: p.profilePhoto || chat.participants[0].profilePhoto, // Use default if not provided
      }));

      chat.participants.push(...validatedParticipants);
      await chat.save();

      group.memberCount += participants.length;
      await group.save();

      return res.json({ message: "Participants added successfully" });
    } catch (error) {
      console.error("Add group participants error:", error);
      return res.status(500).json({ error: "Internal server error" });
    }
  }

  async joinGroupViaInvite(req, res) {
    try {
      const { inviteUrl } = req.params;
      const { userId, userName, profilePhoto } = req.body;

      const group = await Group.findOne({ inviteUrl });
      if (!group) {
        return res.status(404).json({ error: "Invalid invite URL" });
      }

      const chat = await Chat.findById(group.chatId);
      if (chat.participants.some((p) => p.userId === userId)) {
        return res.status(400).json({ error: "Already a member" });
      }

      if (group.memberCount >= 400) {
        return res.status(400).json({ error: "Group is full" });
      }

      chat.participants.push({
        userId,
        userName,
        profilePhoto,
      });
      await chat.save();

      group.memberCount += 1;
      await group.save();

      return res.json({ message: "Joined group successfully" });
    } catch (error) {
      console.error("Join group via invite error:", error);
      return res.status(500).json({ error: "Internal server error" });
    }
  }

  async updateGroupSettings(req, res) {
    try {
      const { groupId } = req.params;
      const { userId, name, description, onlyAdminCanMessage } = req.body;

      const group = await Group.findById(groupId);
      if (!group) {
        return res.status(404).json({ error: "Group not found" });
      }

      if (!group.admin.includes(userId)) {
        return res
          .status(403)
          .json({ error: "Only admins can update settings" });
      }

      Object.assign(group, {
        name: name || group.name,
        description: description || group.description,
        onlyAdminCanMessage: onlyAdminCanMessage ?? group.onlyAdminCanMessage,
      });

      await group.save();
      return res.json(group);
    } catch (error) {
      console.error("Update group settings error:", error);
      return res.status(500).json({ error: "Internal server error" });
    }
  }
}

module.exports = new GroupController();
