const mongoose = require('mongoose');

/**
 * ConsultantRating
 *
 * Per-(user, chat) rating record. Upsertable: a user can revise their
 * rating for the same chat without creating duplicates. Aggregations
 * (average, count, distribution) live in the consultant leaderboard
 * query — we don't denormalize onto the User document.
 */
const consultantRatingSchema = new mongoose.Schema(
  {
    consultantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    // Chat key — scopes the rating to a specific conversation. A user with
    // multiple chats with the same consultant can rate each one separately.
    // Stored as String because chat IDs come from message-svc (ObjectId
    // there) and we don't want a hard cross-service ref.
    chatId: {
      type: String,
      required: true,
    },
    rating: {
      type: Number,
      required: true,
      min: 1,
      max: 5,
    },
    reviewText: {
      type: String,
      maxlength: 1000,
      default: '',
    },
  },
  { timestamps: true }
);

// One rating per (user, chat) pair.
consultantRatingSchema.index({ userId: 1, chatId: 1 }, { unique: true });
// Fast read for "all ratings for this consultant".
consultantRatingSchema.index({ consultantId: 1, createdAt: -1 });

module.exports = mongoose.model('ConsultantRating', consultantRatingSchema);
