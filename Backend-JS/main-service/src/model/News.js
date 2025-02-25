const mongoose = require("mongoose");
 
const NewsSchema = new mongoose.Schema({
    content: {
        type: String,
        required: [true, "News content is required"],
        trim: true,
        minlength: [10, "Content must be at least 10 characters long"]
    },
    image: {
        type: String,
        default: null
    },
    tags: [{
        type: String,
        trim: true,
        lowercase: true
    }],
    createdAt: {
        type: Date,
        default: Date.now,
        immutable: true
    },
    uploadedBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
        required: true
    },
    likes: {
        type: Number,
        default: 0,
        min: [0, "Likes cannot be negative"]
    },
    viewCount: {
        type: Number,
        default: 0
    },
    isPublished: {
        type: Boolean,
        default: true
    }
}, {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true }
});

// Text index for search functionality
NewsSchema.index({ content: 'text', tags: 'text' });

// Virtual for formatted date
NewsSchema.virtual('formattedDate').get(function() {
    return this.createdAt.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    });
});

const News = mongoose.model("News", NewsSchema);
module.exports = News;