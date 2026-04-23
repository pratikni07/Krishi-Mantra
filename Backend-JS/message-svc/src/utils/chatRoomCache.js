const Redis = require("../config/redis");
const Chat = require("../models/chat.model");

// Cache a user's chat-room ID list so a burst of socket reconnects (app
// resume, flaky network) does not hit MongoDB once per connection. Previously
// every connection ran `Chat.find({ "participants.userId": userId })`, which
// is O(n) over that user's chats and scans all participant subdocuments —
// 10k reconnects meant 10k of those scans.
//
// TTL is short: a newly-created chat should appear within the window without
// anyone manually invalidating. Mutating paths (create/add-participants) call
// `invalidate` so the affected users see the update immediately.
const CACHE_TTL_SECONDS = 60;
const keyFor = (userId) => `user:chats:${userId}`;

const loadUserChatIds = async (userId) => {
  const cached = await Redis.getOrSet(keyFor(userId), CACHE_TTL_SECONDS, async () => {
    const chats = await Chat.find({ "participants.userId": userId })
      .select("_id")
      .lean();
    return chats.map((c) => c._id.toString());
  });
  return Array.isArray(cached) ? cached : [];
};

const invalidate = async (userIds) => {
  if (!userIds) return;
  const ids = Array.isArray(userIds) ? userIds : [userIds];
  await Promise.all(ids.filter(Boolean).map((id) => Redis.del(keyFor(id))));
};

module.exports = { loadUserChatIds, invalidate };
