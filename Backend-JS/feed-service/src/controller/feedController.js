const Feed = require("../model/FeedModel");
const mongoose = require("mongoose");
const Comment = require("../model/CommetModel");
const Tag = require("../model/Tags");
const Like = require("../model/LikeModel");
const redis = require("../config/redis");
const UserInterest = require("../model/userInterest");

// Cache keys and duration
const FEED_CACHE_KEY = "feed:";
const COMMENTS_CACHE_KEY = "comments:";
const TAG_CACHE_KEY = "tag:";
const CACHE_DURATION = 3600;
const RANDOM_FEEDS_CACHE_KEY = "random-feeds:";
const RECOMMENDED_FEEDS_CACHE_KEY = "recommended-feeds:";
const USER_INTEREST_CACHE_KEY = "user-interest:";
const MAX_RADIUS_KM = 500;

function extractTags(content) {
  const tagRegex = /#(\w+)/g;
  const matches = content.match(tagRegex);
  return matches ? matches.map((tag) => tag.slice(1).toLowerCase()) : [];
}

function getGridCell(latitude, longitude) {
  const latCell = Math.floor(latitude / LOCATION_GRID_SIZE);
  const lonCell = Math.floor(longitude / LOCATION_GRID_SIZE);
  return `${latCell}:${lonCell}`;
}

class FeedController {
  constructor() {
    // Bind all methods that use 'this' to preserve context
    this.getRandomFeeds = this.getRandomFeeds.bind(this);
    this.manageRandomFeedCache = this.manageRandomFeedCache.bind(this);
    this.invalidateRandomFeedsCache =
      this.invalidateRandomFeedsCache.bind(this);
    this.createFeed = this.createFeed.bind(this);
    this.getFeed = this.getFeed.bind(this);
    this.addComment = this.addComment.bind(this);
    this.toggleLike = this.toggleLike.bind(this);
    this.getFeedsByTag = this.getFeedsByTag.bind(this);
    this.getLocationBasedFeeds = this.getLocationBasedFeeds.bind(this);
    this.getCommonAggregationPipeline =
      this.getCommonAggregationPipeline.bind(this);
    this.getRecommendedFeeds = this.getRecommendedFeeds.bind(this);
    this.getTopFeeds = this.getTopFeeds.bind(this);
  }
  getCommonAggregationPipeline() {
    return [
      {
        $lookup: {
          from: "comments",
          localField: "_id",
          foreignField: "feed",
          pipeline: [{ $match: { parentComment: null } }, { $limit: 10 }],
          as: "recentComments",
        },
      },
      {
        $lookup: {
          from: "likes",
          localField: "_id",
          foreignField: "feed",
          as: "likes",
        },
      },
      {
        $addFields: {
          commentCount: { $size: "$recentComments" },
          likeCount: { $size: "$likes" },
        },
      },
      {
        $project: {
          userId: 1,
          userName: 1,
          profilePhoto: 1,
          description: 1,
          content: 1,
          mediaUrl: 1,
          location: 1,
          date: 1,
          score: 1,
          matchingTags: 1,
          like: {
            count: "$likeCount",
          },
          comment: {
            count: "$commentCount",
          },
          recentComments: 1,
        },
      },
    ];
  }

  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth's radius in kilometers
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  async getLocationBasedFeeds(
    userLocation,
    excludeIds,
    radius,
    page,
    limit,
    skip
  ) {
    const radiusDegrees = radius / 111;

    const feeds = await Feed.aggregate([
      {
        $match: {
          _id: { $nin: excludeIds },
          "location.latitude": {
            $gte: userLocation.latitude - radiusDegrees,
            $lte: userLocation.latitude + radiusDegrees,
          },
          "location.longitude": {
            $gte: userLocation.longitude - radiusDegrees,
            $lte: userLocation.longitude + radiusDegrees,
          },
        },
      },
      {
        $addFields: {
          distance: {
            $sqrt: {
              $add: [
                {
                  $pow: [
                    {
                      $subtract: ["$location.latitude", userLocation.latitude],
                    },
                    2,
                  ],
                },
                {
                  $pow: [
                    {
                      $subtract: [
                        "$location.longitude",
                        userLocation.longitude,
                      ],
                    },
                    2,
                  ],
                },
              ],
            },
          },
        },
      },
      {
        $match: {
          distance: { $lte: radiusDegrees },
        },
      },
      {
        $lookup: {
          from: "comments",
          localField: "_id",
          foreignField: "feed",
          pipeline: [{ $match: { parentComment: null } }, { $limit: 10 }],
          as: "recentComments",
        },
      },
      {
        $lookup: {
          from: "likes",
          localField: "_id",
          foreignField: "feed",
          as: "likes",
        },
      },
      {
        $addFields: {
          commentCount: { $size: "$recentComments" },
          likeCount: { $size: "$likes" },
        },
      },
      {
        $sort: {
          distance: 1,
          date: -1,
        },
      },
      { $skip: skip },
      { $limit: limit },
      {
        $project: {
          userId: 1,
          userName: 1,
          profilePhoto: 1,
          description: 1,
          content: 1,
          mediaUrl: 1,
          location: 1,
          date: 1,
          distance: 1,
          like: {
            count: "$likeCount",
          },
          comment: {
            count: "$commentCount",
          },
          recentComments: 1,
        },
      },
    ]);

    const totalFeeds = await Feed.countDocuments({
      _id: { $nin: excludeIds },
      "location.latitude": {
        $gte: userLocation.latitude - radiusDegrees,
        $lte: userLocation.latitude + radiusDegrees,
      },
      "location.longitude": {
        $gte: userLocation.longitude - radiusDegrees,
        $lte: userLocation.longitude + radiusDegrees,
      },
    });

    return { feeds, totalFeeds };
  }

  async updateUserInterest(req, res) {
    try {
      const { userId, location } = req.body;

      let userInterest = await UserInterest.findOne({ userId });

      if (!userInterest) {
        userInterest = new UserInterest({
          userId,
          location,
          interests: [],
          recentViews: [],
        });
      } else {
        userInterest.location = location;
      }

      await userInterest.save();
      await redis.del(`${USER_INTEREST_CACHE_KEY}${userId}`);

      res.json(userInterest);
    } catch (error) {
      console.error("Error updating user interest:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }

  async recordInteraction(req, res) {
    try {
      const { userId, feedId, interactionType } = req.body;

      const feed = await Feed.findById(feedId);
      if (!feed) {
        return res.status(404).json({ error: "Feed not found" });
      }

      let userInterest = await UserInterest.findOne({ userId });
      if (!userInterest) {
        return res
          .status(404)
          .json({ error: "User interest profile not found" });
      }

      const tags = extractTags(feed.content);
      const interactionScore =
        {
          view: 0.2,
          like: 0.5,
          comment: 1.0,
        }[interactionType] || 0.1;

      // Update interest scores
      for (const tag of tags) {
        const existingInterest = userInterest.interests.find(
          (i) => i.tag === tag
        );
        if (existingInterest) {
          existingInterest.score += interactionScore;
          existingInterest.lastInteraction = new Date();
        } else {
          userInterest.interests.push({
            tag,
            score: interactionScore,
            lastInteraction: new Date(),
          });
        }
      }

      // Record view if it's a new view interaction
      if (interactionType === "view") {
        userInterest.recentViews.push({
          feedId,
          viewedAt: new Date(),
        });

        // Keep only last 100 views
        if (userInterest.recentViews.length > 100) {
          userInterest.recentViews = userInterest.recentViews.slice(-100);
        }
      }

      await userInterest.save();
      await redis.del(`${USER_INTEREST_CACHE_KEY}${userId}`);
      await redis.del(`${RECOMMENDED_FEEDS_CACHE_KEY}${userId}`);

      res.json({ success: true });
    } catch (error) {
      console.error("Error recording interaction:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }

  async getRandomFeeds(req, res) {
    try {
      const page = Math.max(1, parseInt(req.query.page) || 1);
      const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 10));

      // Create a cache key that includes pagination parameters
      const cacheKey = `${RANDOM_FEEDS_CACHE_KEY}${page}:${limit}`;

      // Try to get from cache first
      try {
        const cachedFeeds = await redis.get(cacheKey);
        if (cachedFeeds) {
          return res.json(JSON.parse(cachedFeeds));
        }
      } catch (cacheError) {
        console.error("Cache error:", cacheError);
      }

      // Get total count of feeds
      const totalFeeds = await Feed.countDocuments();

      if (totalFeeds === 0) {
        return res.json({
          feeds: [],
          pagination: {
            currentPage: page,
            totalPages: 0,
            totalFeeds: 0,
            hasMore: false,
          },
        });
      }

      // Calculate skip for random offset while maintaining consistency per page
      const maxSkip = Math.max(0, totalFeeds - limit);
      const baseSkip = ((page - 1) * limit) % (maxSkip + 1);

      // Create a deterministic but seemingly random offset based on page number
      const seed = parseInt(page.toString() + Date.now().toString().slice(-4));
      const randomOffset = seed % Math.max(1, Math.floor(maxSkip / 10));
      const skip = Math.min(maxSkip, baseSkip + randomOffset);

      const feeds = await Feed.aggregate([
        { $skip: skip },
        { $limit: limit },
        {
          $lookup: {
            from: "comments",
            localField: "_id",
            foreignField: "feed",
            pipeline: [{ $match: { parentComment: null } }, { $limit: 10 }],
            as: "recentComments",
          },
        },
        {
          $lookup: {
            from: "likes",
            localField: "_id",
            foreignField: "feed",
            as: "likes",
          },
        },
        {
          $addFields: {
            commentCount: { $size: "$recentComments" },
            likeCount: { $size: "$likes" },
          },
        },
        {
          $project: {
            userId: 1,
            userName: 1,
            profilePhoto: 1,
            description: 1,
            content: 1,
            mediaUrl: 1,
            location: 1,
            date: 1,
            like: {
              count: "$likeCount",
            },
            comment: {
              count: "$commentCount",
            },
            recentComments: { $slice: ["$recentComments", 10] },
          },
        },
      ]).exec();

      const result = {
        feeds,
        pagination: {
          currentPage: page,
          totalPages: Math.ceil(totalFeeds / limit),
          totalFeeds,
          hasMore: page * limit < totalFeeds,
        },
      };

      // Cache the results with expiration
      try {
        await redis.setex(cacheKey, CACHE_DURATION, JSON.stringify(result));
        await this.manageRandomFeedCache(page);
      } catch (cacheError) {
        console.error("Cache save error:", cacheError);
      }

      res.json(result);
    } catch (error) {
      console.error("Error fetching random feeds:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }

  async manageRandomFeedCache(currentPage) {
    try {
      // Get all random feed cache keys using the Redis client
      const keys = await redis.client.keys(`${RANDOM_FEEDS_CACHE_KEY}*`);

      // Keep only the current page and adjacent pages in cache
      for (const key of keys) {
        const pagePart = key.split(":")[1];
        const page = parseInt(pagePart);

        if (Math.abs(page - currentPage) > 2) {
          // Remove cache for pages that are far from current page
          await redis.del(key);
        }
      }
    } catch (error) {
      console.error("Error managing random feed cache:", error);
      // Continue execution even if cache management fails
    }
  }

  async invalidateRandomFeedsCache() {
    try {
      // Get all random feed cache keys
      const keys = await redis.client.keys(`${RANDOM_FEEDS_CACHE_KEY}*`);

      if (keys.length > 0) {
        await Promise.all(keys.map((key) => redis.del(key)));
      }
    } catch (error) {
      console.error("Error invalidating random feeds cache:", error);
    }
  }
  async createFeed(req, res) {
    try {
      const {
        userId,
        userName,
        profilePhoto,
        description,
        content,
        mediaUrl,
        location,
      } = req.body;

      const feed = new Feed({
        userId,
        userName,
        profilePhoto,
        description,
        content,
        mediaUrl,
        location: {
          latitude: location.latitude,
          longitude: location.longitude,
        },
        like: { count: 0 },
        comment: { count: 0 },
      });

      await feed.save();

      const tags = extractTags(content);

      // Handle tags with proper error checking
      for (const tagName of tags) {
        try {
          // Use findOneAndUpdate instead of findOne
          const tag = await Tag.findOneAndUpdate(
            { name: tagName },
            {
              $setOnInsert: { name: tagName },
              $addToSet: { feedId: feed._id },
            },
            {
              upsert: true,
              new: true,
            }
          );

          await redis.del(`${TAG_CACHE_KEY}${tagName}`);
        } catch (err) {
          console.error(`Error processing tag ${tagName}:`, err);
          continue;
        }
      }

      await redis.setex(
        `${FEED_CACHE_KEY}${feed._id}`,
        CACHE_DURATION,
        JSON.stringify(feed)
      );
      await this.invalidateRandomFeedsCache();

      res.status(201).json(feed);
    } catch (error) {
      console.error("Error creating feed:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }

  async getFeed(req, res) {
    try {
      const { feedId } = req.params;

      // Validate if feedId is a valid ObjectId
      if (!mongoose.Types.ObjectId.isValid(feedId)) {
        return res.status(400).json({ error: "Invalid feed ID format" });
      }

      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 10;
      const skip = (page - 1) * limit;
      // Try to get feed from cache
      const cachedFeed = await redis.get(`${FEED_CACHE_KEY}${feedId}`);
      let feed;

      if (cachedFeed) {
        feed = JSON.parse(cachedFeed);
      } else {
        feed = await Feed.findById(feedId);
        if (!feed) {
          return res.status(404).json({ error: "Feed not found" });
        }

        // Cache the feed
        await redis.setex(
          `${FEED_CACHE_KEY}${feedId}`,
          CACHE_DURATION,
          JSON.stringify(feed)
        );
      }

      // Try to get comments from cache
      const cacheKey = `${COMMENTS_CACHE_KEY}${feedId}:${page}:${limit}`;
      const cachedComments = await redis.get(cacheKey);
      let comments;

      if (cachedComments) {
        comments = JSON.parse(cachedComments);
      } else {
        comments = await Comment.find({ feed: feedId, parentComment: null })
          .sort({ createdAt: -1 })
          .skip(skip)
          .limit(limit)
          .populate({
            path: "replies",
            options: { limit: 5, sort: { createdAt: -1 } },
          });

        // Cache the comments
        await redis.setex(cacheKey, CACHE_DURATION, JSON.stringify(comments));
      }

      const totalComments = await Comment.countDocuments({
        feed: feedId,
        parentComment: null,
      });

      res.json({
        feed,
        comments,
        pagination: {
          currentPage: page,
          totalPages: Math.ceil(totalComments / limit),
          totalComments,
        },
      });
    } catch (error) {
      console.error("Error fetching feed:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }

  async addComment(req, res) {
    try {
      const { feedId } = req.params;
      const { userId, userName, profilePhoto, content, parentCommentId } =
        req.body;

      let depth = 0;
      if (parentCommentId) {
        const parentComment = await Comment.findById(parentCommentId);
        if (!parentComment) {
          return res.status(404).json({ error: "Parent comment not found" });
        }
        depth = parentComment.depth + 1;
        if (depth > 5) {
          return res
            .status(400)
            .json({ error: "Maximum comment depth reached" });
        }
      }

      const comment = new Comment({
        userId,
        userName,
        profilePhoto,
        feed: feedId,
        content,
        parentComment: parentCommentId,
        depth,
      });

      await comment.save();

      if (parentCommentId) {
        await Comment.findByIdAndUpdate(parentCommentId, {
          $push: { replies: comment._id },
        });
      }

      await Feed.findByIdAndUpdate(feedId, {
        $inc: { "comment.count": 1 },
      });

      // Invalidate feed and comments cache
      await redis.del(`${FEED_CACHE_KEY}${feedId}`);
      const keys = await redis.client.keys(`${COMMENTS_CACHE_KEY}${feedId}:*`);
      if (keys.length > 0) {
        await redis.del(keys);
      }

      res.status(201).json(comment);
    } catch (error) {
      console.error("Error adding comment:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }

  async toggleLike(req, res) {
    try {
      const { feedId } = req.params;
      const { userId, userName, profilePhoto } = req.body;

      const existingLike = await Like.findOne({ feed: feedId, userId });

      if (existingLike) {
        await Like.deleteOne({ _id: existingLike._id });
        await Feed.findByIdAndUpdate(feedId, {
          $inc: { "like.count": -1 },
        });
      } else {
        const like = new Like({
          userId,
          userName,
          profilePhoto,
          feed: feedId,
        });
        await like.save();
        await Feed.findByIdAndUpdate(feedId, {
          $inc: { "like.count": 1 },
        });
      }

      // Invalidate feed cache
      await redis.del(`${FEED_CACHE_KEY}${feedId}`);

      res.json({ success: true });
    } catch (error) {
      console.error("Error processing like:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }

  async getFeedsByTag(req, res) {
    try {
      const { tagName } = req.params;
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 10;
      const skip = (page - 1) * limit;

      const cacheKey = `${TAG_CACHE_KEY}${tagName}:${page}:${limit}`;
      const cachedResult = await redis.get(cacheKey);

      if (cachedResult) {
        return res.json(JSON.parse(cachedResult));
      }

      const tag = await Tag.findOne({ name: tagName }).populate({
        path: "feedId",
        options: {
          skip,
          limit,
          sort: { date: -1 },
        },
      });

      if (!tag) {
        return res.status(404).json({ error: "Tag not found" });
      }

      const totalFeeds = tag.feedId.length;
      const result = {
        feeds: tag.feedId,
        pagination: {
          currentPage: page,
          totalPages: Math.ceil(totalFeeds / limit),
          totalFeeds,
        },
      };

      // Cache the result
      await redis.setex(cacheKey, CACHE_DURATION, JSON.stringify(result));

      res.json(result);
    } catch (error) {
      console.error("Error fetching feeds by tag:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }

  async getRecommendedFeeds(req, res) {
    try {
      const { userId } = req.params;
      const page = Math.max(1, parseInt(req.query.page) || 1);
      const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 10));
      const skip = (page - 1) * limit;

      // Try to get cached recommendations
      const cacheKey = `${RECOMMENDED_FEEDS_CACHE_KEY}${userId}:${page}:${limit}`;
      const cachedRecommendations = await redis.get(cacheKey);

      if (cachedRecommendations) {
        return res.json(JSON.parse(cachedRecommendations));
      }

      // Get user interests and location
      const userInterest = await UserInterest.findOne({ userId });
      let feeds = [];
      let totalFeeds = 0;
      let recommendationType = "";

      // Keep track of feeds we've already shown to avoid duplicates
      const viewedFeeds =
        userInterest?.recentViews?.map((view) => view.feedId) || [];

      // 1. Try interest-based recommendations first
      if (userInterest && userInterest.interests.length > 0) {
        recommendationType = "interest";
        // Sort interests by score and recency
        const weightedInterests = userInterest.interests
          .map((interest) => ({
            ...interest,
            weightedScore:
              interest.score *
              Math.exp(
                -(
                  (Date.now() - new Date(interest.lastInteraction)) /
                  (1000 * 60 * 60 * 24 * 7)
                )
              ),
          }))
          .sort((a, b) => b.weightedScore - a.weightedScore);

        // Get top tags
        const topTags = weightedInterests.slice(0, 5).map((i) => i.tag);

        // Find feeds with matching tags
        const tagFeeds = await Feed.aggregate([
          {
            $match: {
              _id: { $nin: viewedFeeds },
              content: {
                $regex: new RegExp(
                  topTags.map((tag) => `#${tag}`).join("|"),
                  "i"
                ),
              },
            },
          },
          {
            $addFields: {
              matchingTags: {
                $size: {
                  $setIntersection: [
                    topTags,
                    {
                      $map: {
                        input: {
                          $regexFind: { input: "$content", regex: /#(\w+)/g },
                        },
                        as: "tag",
                        in: { $toLower: { $substr: ["$$tag", 1, -1] } },
                      },
                    },
                  ],
                },
              },
            },
          },
          { $sort: { matchingTags: -1, date: -1 } },
          { $skip: skip },
          { $limit: limit },
          ...this.getCommonAggregationPipeline(),
        ]);

        if (tagFeeds.length > 0) {
          feeds = tagFeeds;
          totalFeeds = await Feed.countDocuments({
            _id: { $nin: viewedFeeds },
            content: {
              $regex: new RegExp(
                topTags.map((tag) => `#${tag}`).join("|"),
                "i"
              ),
            },
          });
        }
      }

      // 2. Try location-based recommendations if interest-based failed
      if (feeds.length === 0 && userInterest?.location) {
        recommendationType = "location";
        const { location } = userInterest;
        const radius = 50; // Start with 50km radius

        const locationResults = await this.getLocationBasedFeeds(
          location,
          viewedFeeds,
          radius,
          page,
          limit,
          skip
        );

        if (locationResults.feeds.length > 0) {
          feeds = locationResults.feeds;
          totalFeeds = locationResults.totalFeeds;
        }
      }

      // 3. Fallback to trending/random posts if both above methods fail
      if (feeds.length === 0) {
        recommendationType = "trending";
        feeds = await Feed.aggregate([
          {
            $match: {
              _id: { $nin: viewedFeeds },
            },
          },
          {
            $addFields: {
              score: {
                $add: [
                  { $multiply: ["$like.count", 2] },
                  { $multiply: ["$comment.count", 3] },
                  {
                    $multiply: [
                      {
                        $divide: [
                          1,
                          { $add: [1, { $subtract: [new Date(), "$date"] }] },
                        ],
                      },
                      86400000,
                    ],
                  },
                ],
              },
            },
          },
          { $sort: { score: -1, date: -1 } },
          { $skip: skip },
          { $limit: limit },
          ...this.getCommonAggregationPipeline(),
        ]);

        totalFeeds = await Feed.countDocuments({
          _id: { $nin: viewedFeeds },
        });
      }

      const result = {
        feeds,
        recommendationType,
        pagination: {
          currentPage: page,
          totalPages: Math.ceil(totalFeeds / limit),
          totalFeeds,
          hasMore: page * limit < totalFeeds,
        },
      };

      // Cache the results
      await redis.setex(cacheKey, CACHE_DURATION, JSON.stringify(result));

      res.json(result);
    } catch (error) {
      console.error("Error fetching recommended feeds:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }
  async getTopFeeds(req, res) {
    try {
      const topFeeds = await Feed.aggregate([
        {
          $addFields: {
            totalEngagement: {
              $add: ["$like.count", "$comment.count"],
            },
          },
        },
        {
          $sort: {
            totalEngagement: -1,
          },
        },
        {
          $limit: 2,
        },
        {
          $project: {
            userId: 1,
            userName: 1,
            profilePhoto: 1,
            description: 1,
            content: 1,
            mediaUrl: 1,
            like: 1,
            comment: 1,
            location: 1,
            date: 1,
            totalEngagement: 1,
          },
        },
      ]);

      // Add null checks for like.count and comment.count
      const sanitizedTopFeeds = topFeeds.map((feed) => ({
        ...feed,
        like: {
          count: feed.like?.count || 0,
        },
        comment: {
          count: feed.comment?.count || 0,
        },
      }));

      if (!sanitizedTopFeeds.length) {
        return res.status(404).json({
          success: false,
          message: "No feeds found",
        });
      }

      return res.status(200).json({
        success: true,
        data: sanitizedTopFeeds,
        message: "Top feeds retrieved successfully",
      });
    } catch (error) {
      console.error("Error in getTopFeeds:", error);
      return res.status(500).json({
        success: false,
        message: "Error retrieving top feeds",
        error: error.message,
      });
    }
  }
}

module.exports = new FeedController();
