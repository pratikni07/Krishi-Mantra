const mongoose = require("mongoose");

const aiMessageSchema = new mongoose.Schema(
  {
    role: {
      type: String,
      enum: ["user", "assistant", "system"],
      required: true,
    },
    content: {
      type: String,
      required: true,
    },
    imageUrl: {
      type: String,
    },
    timestamp: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

const aiChatSchema = new mongoose.Schema(
  {
    userId: {
      type: String,
      required: true,
      index: true,
    },
    userName: {
      type: String,
      required: true,
    },
    userProfilePhoto: {
      type: String,
      default:
        "https://media.istockphoto.com/id/1269841295/photo/side-view-of-a-senior-farmer-standing-in-corn-field-examining-crop-at-sunset.jpg?s=612x612&w=0&k=20&c=Lheldd6VVGQGxrgC8_mwUTLxXGg9v8Y6abjmYLhLHug=",
    },
    title: {
      type: String,
      default: "New Conversation",
    },
    messages: [aiMessageSchema],
    context: {
      currentTopic: {
        type: String,
        default: "",
      },
      lastContext: {
        type: String,
        default: "",
      },
      identifiedIssues: [
        {
          type: String,
        },
      ],
      suggestedSolutions: [
        {
          type: String,
        },
      ],
    },
    metadata: {
      preferredLanguage: {
        type: String,
        default: "en",
      },
      location: {
        lat: Number,
        lon: Number,
      },
      weather: {
        temperature: Number,
        humidity: Number,
      },
    },
    lastMessageAt: {
      type: Date,
      default: Date.now,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    dailyMessageCount: {
      count: {
        type: Number,
        default: 0,
      },
      lastResetDate: {
        type: Date,
        default: Date.now,
      },
    },
  },
  { timestamps: true }
);

// Update lastMessageAt when new messages are added
aiChatSchema.pre("save", function (next) {
  if (this.messages && this.messages.length > 0) {
    this.lastMessageAt = new Date();

    // Update chat title based on first user message if it's still default
    if (this.title === "New Conversation" && this.messages.length === 2) {
      const firstUserMessage = this.messages[0].content;
      this.title =
        firstUserMessage.length > 50
          ? firstUserMessage.substring(0, 50) + "..."
          : firstUserMessage;
    }
  }
  next();
});

// Index for efficient querying
aiChatSchema.index({ userId: 1, lastMessageAt: -1 });
aiChatSchema.index({ isActive: 1 });

module.exports = mongoose.model("AIChat", aiChatSchema);
