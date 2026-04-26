const mongoose = require('mongoose');
const DailyActionCard = require('../../model/DailyActionCard');

let logger;
try {
  logger = require('../../utils/logger');
} catch (err) {
  logger = { info: () => {}, warn: () => {}, error: () => {}, debug: () => {} };
}

const DEFAULT_LOOKBACK_DAYS = 7;
const MAX_IMAGES = 5;
const VALID_URL_RE = /^https?:\/\//i;
const DATA_URL_RE = /^data:image\//i;

// We don't import message-svc's models — read raw from the shared Mongo
// connection. `strict: false` so future schema additions don't break us.
let AIChatRO = null;
let MessageRO = null;
let ChatRO = null;

function lazyAIChat() {
  if (AIChatRO) return AIChatRO;
  try {
    AIChatRO = mongoose.model('AIChatActionCardRO');
  } catch (_) {
    const { Schema } = mongoose;
    const schema = new Schema(
      {
        userId: String,
        messages: [Schema.Types.Mixed],
        updatedAt: Date,
      },
      { strict: false, collection: 'aichats', timestamps: true }
    );
    AIChatRO = mongoose.model('AIChatActionCardRO', schema);
  }
  return AIChatRO;
}

function lazyMessage() {
  if (MessageRO) return MessageRO;
  try {
    MessageRO = mongoose.model('MessageActionCardRO');
  } catch (_) {
    const { Schema } = mongoose;
    const schema = new Schema(
      {
        chatId: Schema.Types.ObjectId,
        sender: String,
        mediaType: String,
        mediaUrl: String,
        mediaMetadata: Schema.Types.Mixed,
        content: String,
        createdAt: Date,
      },
      { strict: false, collection: 'messages', timestamps: true }
    );
    MessageRO = mongoose.model('MessageActionCardRO', schema);
  }
  return MessageRO;
}

function lazyChat() {
  if (ChatRO) return ChatRO;
  try {
    ChatRO = mongoose.model('ChatActionCardRO');
  } catch (_) {
    const { Schema } = mongoose;
    const schema = new Schema(
      {
        participants: [String],
        members: [String],
        userIds: [String],
      },
      { strict: false, collection: 'chats', timestamps: true }
    );
    ChatRO = mongoose.model('ChatActionCardRO', schema);
  }
  return ChatRO;
}

function looksLikeImageUrl(s) {
  if (!s || typeof s !== 'string') return false;
  if (VALID_URL_RE.test(s)) return true;
  if (DATA_URL_RE.test(s)) return true;
  return false;
}

function safeIso(d) {
  try {
    return new Date(d).toISOString();
  } catch (_) {
    return null;
  }
}

async function collectFromAIChat(userId, since) {
  const out = [];
  try {
    const chats = await lazyAIChat()
      .find({ userId: String(userId), updatedAt: { $gte: since } })
      .sort({ updatedAt: -1 })
      .limit(50)
      .lean();
    for (const chat of chats) {
      for (const m of chat.messages || []) {
        const url = m?.imageUrl;
        if (!looksLikeImageUrl(url)) continue;
        // Skip the placeholder marker the legacy AI controller emits.
        if (url === 'image_upload') continue;
        out.push({
          url,
          source: 'ai_chat',
          chatId: String(chat._id),
          messageRole: m.role || null,
          occurredAt: m.timestamp || m.createdAt || chat.updatedAt,
          caption: typeof m.content === 'string' ? m.content.slice(0, 120) : '',
        });
      }
    }
  } catch (err) {
    logger.warn?.('image-context.ai_chat_read_failed', { error: err.message });
  }
  return out;
}

async function collectFromConsultantChat(userId, since) {
  const out = [];
  try {
    const Chat = lazyChat();
    const Message = lazyMessage();
    // Find chats this user participates in. The consultant chat schema in
    // message-svc varies a bit (`participants` historically); try multiple
    // shapes to be defensive.
    const chats = await Chat.find({
      $or: [
        { participants: String(userId) },
        { members: String(userId) },
        { 'participants.userId': String(userId) },
        { userIds: String(userId) },
      ],
    })
      .select('_id')
      .lean();
    if (!chats.length) return out;
    const chatIds = chats.map((c) => c._id);

    const msgs = await Message.find({
      chatId: { $in: chatIds },
      mediaType: { $in: ['image', 'text_image'] },
      mediaUrl: { $exists: true, $ne: null },
      createdAt: { $gte: since },
    })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();

    for (const m of msgs) {
      if (!looksLikeImageUrl(m.mediaUrl)) continue;
      out.push({
        url: m.mediaUrl,
        source: 'consultant_chat',
        chatId: String(m.chatId),
        messageRole: m.sender === String(userId) ? 'user' : 'consultant',
        occurredAt: m.createdAt,
        caption: m.content ? String(m.content).slice(0, 120) : '',
      });
    }
  } catch (err) {
    logger.warn?.('image-context.consultant_chat_read_failed', { error: err.message });
  }
  return out;
}

async function collectFromFarmerInputs(userId, since) {
  const out = [];
  try {
    const cards = await DailyActionCard.find({
      userId,
      'farmerInput.submittedAt': { $gte: since },
    })
      .sort({ 'farmerInput.submittedAt': -1 })
      .limit(14)
      .lean();
    for (const c of cards) {
      const fi = c.farmerInput || {};
      if (!Array.isArray(fi.imageUrls) || !fi.imageUrls.length) continue;
      for (const url of fi.imageUrls) {
        if (!looksLikeImageUrl(url)) continue;
        out.push({
          url,
          source: 'farmer_input',
          cardLocalDate: c.localDate,
          messageRole: 'user',
          occurredAt: fi.submittedAt,
          caption: typeof fi.text === 'string' ? fi.text.slice(0, 120) : '',
        });
      }
    }
  } catch (err) {
    logger.warn?.('image-context.farmer_input_read_failed', { error: err.message });
  }
  return out;
}

function dedupeByUrl(items) {
  const seen = new Set();
  const out = [];
  for (const it of items) {
    if (seen.has(it.url)) continue;
    seen.add(it.url);
    out.push(it);
  }
  return out;
}

function pickRecentDiverse(items, max = MAX_IMAGES) {
  // Group by source to ensure variety; then merge recency-first per group.
  const bySource = new Map();
  for (const it of items) {
    const list = bySource.get(it.source) || [];
    list.push(it);
    bySource.set(it.source, list);
  }
  for (const list of bySource.values()) {
    list.sort((a, b) => new Date(b.occurredAt) - new Date(a.occurredAt));
  }

  const sources = Array.from(bySource.keys());
  const out = [];
  let i = 0;
  // Round-robin until we hit the cap or run out.
  while (out.length < max && sources.some((s) => bySource.get(s)?.length)) {
    const src = sources[i % sources.length];
    const list = bySource.get(src);
    if (list?.length) out.push(list.shift());
    i += 1;
    if (i > 50) break; // safety
  }
  return out;
}

/**
 * Collect last-N-days image context for a user.
 *
 * Returns:
 *   {
 *     images: [{ url, source, occurredAt, caption, messageRole }],
 *     totalSeen: number,
 *     sources: { ai_chat, consultant_chat, farmer_input }
 *   }
 */
async function collect(userId, { lookbackDays = DEFAULT_LOOKBACK_DAYS, max = MAX_IMAGES } = {}) {
  if (!userId) return { images: [], totalSeen: 0, sources: {} };
  const since = new Date(Date.now() - lookbackDays * 24 * 60 * 60 * 1000);

  const [a, b, c] = await Promise.all([
    collectFromAIChat(userId, since),
    collectFromConsultantChat(userId, since),
    collectFromFarmerInputs(userId, since),
  ]);

  const all = dedupeByUrl([...a, ...b, ...c]);
  const picked = pickRecentDiverse(all, max);

  const sources = picked.reduce((acc, it) => {
    acc[it.source] = (acc[it.source] || 0) + 1;
    return acc;
  }, {});

  return {
    images: picked.map((it) => ({
      url: it.url,
      source: it.source,
      occurredAt: safeIso(it.occurredAt),
      caption: it.caption || '',
      messageRole: it.messageRole || null,
    })),
    totalSeen: all.length,
    sources,
    lookbackDays,
  };
}

module.exports = {
  collect,
  // Exported for tests:
  _internal: { dedupeByUrl, pickRecentDiverse, looksLikeImageUrl },
};
