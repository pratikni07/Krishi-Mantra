const Feed = require("../model/FeedModel");
const mongoose = require("mongoose");
const Comment = require("../model/CommetModel");
const Tag = require("../model/Tags");
const Like = require("../model/LikeModel");
const redis = require("../config/redis");
const UserInterest = require("../model/userInterest");

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
    this.getTrendingHashtags = this.getTrendingHashtags.bind(this);
  }
  getCommonAggregationPipeline() {
    return [
      {
        $lookup: {
          from: "comments",
          localField: "_id",
          foreignField: "feed",
          pipeline: [
            { $match: { parentComment: null, isDeleted: false } }, 
            { $sort: { createdAt: -1 } },
            { $limit: 3 }
          ],
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
          viewCount: { $ifNull: ["$views.count", 0] },
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
          relevanceScore: 1,
          distance: 1,
          discoveryScore: 1,
          like: {
            count: "$likeCount",
          },
          comment: {
            count: "$commentCount",
          },
          views: {
            count: "$viewCount",
            lastViewed: 1
          },
          recentComments: {
            $map: {
              input: "$recentComments",
              as: "comment",
              in: {
                _id: "$$comment._id",
                userId: "$$comment.userId",
                userName: "$$comment.userName",
                content: "$$comment.content",
                createdAt: "$$comment.createdAt",
                profilePhoto: "$$comment.profilePhoto"
              }
            }
          },
        },
      },
    ];
  }

  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371;
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
    try {
      const radiusDegrees = radius / 111; // Roughly convert km to degrees

      // Use MongoDB's geospatial queries with optimized matching
      const feeds = await Feed.aggregate([
        {
          $match: {
            _id: { $nin: excludeIds },
            // Only include posts that have location data
            "location.latitude": { $exists: true, $ne: null },
            "location.longitude": { $exists: true, $ne: null },
            // First filter by a bounding box (more efficient than calculating distance for all docs)
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
            // Calculate more accurate distance using Haversine formula approximation
            distance: {
              $sqrt: {
                $add: [
                  {
                    $pow: [
                      { $multiply: [
                        { $subtract: ["$location.latitude", userLocation.latitude] },
                        111 // km per degree latitude (approximate)
                      ]},
                      2,
                    ],
                  },
                  {
                    $pow: [
                      { $multiply: [
                        { $subtract: ["$location.longitude", userLocation.longitude] },
                        // Adjust for longitude distance variation by latitude
                        { $multiply: [
                          111, 
                          { $cos: { $multiply: [userLocation.latitude, 3.14159 / 180] } }
                        ]}
                      ]},
                      2,
                    ],
                  },
                ],
              },
            },
            // Calculate post freshness (recency factor)
            recencyScore: {
              $divide: [
                1,
                { 
                  $add: [
                    1, 
                    { 
                      $divide: [
                        { $subtract: [new Date(), "$date"] },
                        1000 * 60 * 60 * 24 // Convert ms to days
                      ] 
                    }
                  ] 
                }
              ]
            },
            // Calculate engagement score
            engagementScore: {
              $add: [
                { $ifNull: ["$views.count", 0] },
                { $multiply: [{ $ifNull: ["$like.count", 0] }, 3] },
                { $multiply: [{ $ifNull: ["$comment.count", 0] }, 5] }
              ]
            }
          },
        },
        {
          $match: {
            distance: { $lte: radius }, // Filter by actual calculated distance
          },
        },
        {
          $addFields: {
            // Combined relevance score weighing distance, recency and engagement
            relevanceScore: {
              $add: [
                // Distance matters most (inverted: closer = higher score)
                { $multiply: [{ $subtract: [radius, "$distance"] }, 10 / radius] },
                // Recency is important
                { $multiply: ["$recencyScore", 5] },
                // Engagement matters too
                { $multiply: [{ $log10: { $add: ["$engagementScore", 1] } }, 2] }
              ]
            }
          }
        },
        { $sort: { relevanceScore: -1 } },
        { $skip: skip },
        { $limit: limit },
        ...this.getCommonAggregationPipeline(),
      ]);

      const totalFeeds = await Feed.countDocuments({
        _id: { $nin: excludeIds },
        "location.latitude": { $exists: true, $ne: null },
        "location.longitude": { $exists: true, $ne: null },
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
    } catch (error) {
      console.error("Error in getLocationBasedFeeds:", error);
      return { feeds: [], totalFeeds: 0 };
    }
  }

  async updateUserInterest(req, res) {
    try {
      const { userId, location } = req.body;

      let userInterest = await UserInterest.findOne({ userId });

      if (!userInterest) {
        userInterest = new UserInterest({
          userId,
          // Only set location if provided
          ...(location && { 
            location: {
              ...location,
              lastUpdated: new Date()
            }
          }),
          interests: [],
          recentViews: [],
        });
      } else if (location) {
        // Only update location if provided
        userInterest.location = {
          ...location,
          lastUpdated: new Date()
        };
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
        userInterest = new UserInterest({
          userId,
          interests: [],
          recentViews: [],
        });
      }

      // Update user's last active timestamp
      userInterest.lastActive = new Date();

      const tags = extractTags(feed.content);
      const interactionScore = {
        view: 0.2,
        like: 0.5,
        comment: 1.0,
        share: 1.5,
        save: 1.2,
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

      // Record view and increment view count on feed
      if (interactionType === "view") {
        // Check if user has already viewed this feed
        const alreadyViewed = userInterest.recentViews.some(
          (view) => view.feedId.toString() === feedId.toString()
        );

        if (!alreadyViewed) {
          // Increment feed view count if this is a new view
          await Feed.findByIdAndUpdate(feedId, {
            $inc: { "views.count": 1 },
            $set: { "views.lastViewed": new Date() },
          });
        }

        // Add to recent views regardless (to update timestamp)
        const viewIndex = userInterest.recentViews.findIndex(
          (view) => view.feedId.toString() === feedId.toString()
        );

        if (viewIndex >= 0) {
          // Update existing view timestamp
          userInterest.recentViews[viewIndex].viewedAt = new Date();
        } else {
          // Add new view
          userInterest.recentViews.push({
            feedId,
            viewedAt: new Date(),
          });
        }

        // Keep only the most recent 500 views (to avoid unbounded growth)
        if (userInterest.recentViews.length > 500) {
          userInterest.recentViews = userInterest.recentViews
            .sort((a, b) => b.viewedAt - a.viewedAt)
            .slice(0, 500);
        }
      }

      // Calculate user engagement level based on interaction patterns
      const lastMonthInteractions = userInterest.recentViews.filter(
        (view) => new Date() - new Date(view.viewedAt) < 30 * 24 * 60 * 60 * 1000
      ).length;

      if (lastMonthInteractions > 100) {
        userInterest.engagementLevel = "high";
      } else if (lastMonthInteractions > 30) {
        userInterest.engagementLevel = "medium";
      } else {
        userInterest.engagementLevel = "low";
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

      const cacheKey = `${RANDOM_FEEDS_CACHE_KEY}${page}:${limit}`;

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

      const maxSkip = Math.max(0, totalFeeds - limit);
      const baseSkip = ((page - 1) * limit) % (maxSkip + 1);

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
      const keys = await redis.client.keys(`${RANDOM_FEEDS_CACHE_KEY}*`);
      for (const key of keys) {
        const pagePart = key.split(":")[1];
        const page = parseInt(pagePart);

        if (Math.abs(page - currentPage) > 2) {
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

      const feedData = {
        userId,
        userName,
        profilePhoto,
        description,
        content,
        mediaUrl,
        like: { count: 0 },
        comment: { count: 0 },
      };

      if (
        location &&
        (location.latitude !== undefined || location.longitude !== undefined)
      ) {
        feedData.location = {
          latitude: location.latitude ? parseFloat(location.latitude) : null,
          longitude: location.longitude ? parseFloat(location.longitude) : null,
        };
      }

      const feed = new Feed(feedData);
      await feed.save();

      const tags = extractTags(content);
      for (const tagName of tags) {
        try {
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

      if (!mongoose.Types.ObjectId.isValid(feedId)) {
        return res.status(400).json({ error: "Invalid feed ID format" });
      }

      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 10;
      const skip = (page - 1) * limit;
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

      // Tget comments from cache
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

        // Track this as an "unlike" interaction
        if (userId) {
          await this.recordInteraction({
            body: { userId, feedId, interactionType: "unlike" }
          }, { json: () => {} });
        }
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

        // Track this as a "like" interaction
        if (userId) {
          await this.recordInteraction({
            body: { userId, feedId, interactionType: "like" }
          }, { json: () => {} });
        }
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
      const page = Math.max(1, parseInt(req.query.page) || 1);
      const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 10));
      const skip = (page - 1) * limit;

      const cacheKey = `${TAG_CACHE_KEY}${tagName}:${page}:${limit}`;
      const cachedResult = await redis.get(cacheKey);

      if (cachedResult) {
        return res.json(JSON.parse(cachedResult));
      }
      const tag = await Tag.findOne({ name: tagName.toLowerCase() });

      if (!tag) {
        return res.status(404).json({
          success: false,
          message: "Tag not found",
          error: "The requested hashtag does not exist",
        });
      }

      const feeds = await Feed.aggregate([
        { $match: { _id: { $in: tag.feedId } } },
        { $sort: { date: -1 } },
        { $skip: skip },
        { $limit: limit },
        ...this.getCommonAggregationPipeline(),
      ]);

      const totalFeeds = tag.feedId.length;
      const result = {
        success: true,
        message: "Feeds retrieved successfully",
        data: {
          feeds,
          tag: {
            name: tag.name,
            totalPosts: totalFeeds,
          },
          pagination: {
            currentPage: page,
            totalPages: Math.ceil(totalFeeds / limit),
            totalFeeds,
            hasMore: page * limit < totalFeeds,
            limit,
          },
          metadata: {
            timestamp: new Date(),
            source: "tag-based",
          },
        },
      };

      // Cache the result
      await redis.setex(cacheKey, CACHE_DURATION, JSON.stringify(result));

      res.json(result);
    } catch (error) {
      console.error("Error fetching feeds by tag:", error);
      res.status(500).json({
        success: false,
        message: "Error fetching feeds by tag",
        error: error.message,
      });
    }
  }

  async getTrendingHashtags(req, res) {
    try {
      const cacheKey = "trending-hashtags";
      const cachedTags = await redis.get(cacheKey);

      if (cachedTags) {
        return res.json(JSON.parse(cachedTags));
      }

      // Get trending hashtags based on recent feed activity
      const trendingTags = await Tag.aggregate([
        {
          $lookup: {
            from: "feeds",
            localField: "feedId",
            foreignField: "_id",
            as: "feeds",
          },
        },
        {
          $project: {
            name: 1,
            feedCount: { $size: "$feedId" },
            // Calculate engagement score based on likes and comments
            totalEngagement: {
              $reduce: {
                input: "$feeds",
                initialValue: 0,
                in: {
                  $add: [
                    "$$value",
                    { $add: ["$$this.like.count", "$$this.comment.count"] },
                  ],
                },
              },
            },
            // Get the timestamp of the most recent feed
            lastActivity: { $max: "$feeds.date" },
            // Get recent posts count (last 24 hours)
            recentPostsCount: {
              $size: {
                $filter: {
                  input: "$feeds",
                  as: "feed",
                  cond: {
                    $gte: [
                      "$$feed.date",
                      { $subtract: [new Date(), 1000 * 60 * 60 * 24] },
                    ],
                  },
                },
              },
            },
          },
        },
        {
          $addFields: {
            // Calculate trending score based on engagement, recency and recent posts
            trendingScore: {
              $multiply: [
                {
                  $add: [
                    "$totalEngagement",
                    { $multiply: ["$recentPostsCount", 10] },
                  ],
                },
                {
                  $divide: [
                    1,
                    {
                      $add: [
                        1,
                        {
                          $divide: [
                            { $subtract: [new Date(), "$lastActivity"] },
                            1000 * 60 * 60, // Convert to hours
                          ],
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          },
        },
        { $sort: { trendingScore: -1 } },
        { $limit: 10 },
        {
          $project: {
            name: 1,
            feedCount: 1,
            totalEngagement: 1,
            recentPostsCount: 1,
            trendingScore: 1,
            lastActivity: 1,
          },
        },
      ]);

      const result = {
        success: true,
        message: "Trending hashtags retrieved successfully",
        data: {
          trendingTags: trendingTags.map((tag) => ({
            ...tag,
            trendingScore: Math.round(tag.trendingScore * 100) / 100,
            lastActivity: tag.lastActivity,
            metrics: {
              totalPosts: tag.feedCount,
              totalEngagement: tag.totalEngagement,
              recentPosts: tag.recentPostsCount,
            },
          })),
          metadata: {
            timestamp: new Date(),
            refreshInterval: "1 hour",
            algorithm: "engagement-recency-weighted",
          },
        },
      };

      // Cache the results for 1 hour
      await redis.setex(cacheKey, 3600, JSON.stringify(result));

      res.json(result);
    } catch (error) {
      console.error("Error fetching trending hashtags:", error);
      res.status(500).json({
        success: false,
        message: "Error fetching trending hashtags",
        error: error.message,
      });
    }
  }

  async getRecommendedFeeds(req, res) {
    try {
      const { userId } = req.params;
      const page = Math.max(1, parseInt(req.query.page) || 1);
      const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 10));
      const skip = (page - 1) * limit;
      const shuffle = req.query.shuffle !== "false"; // Default to true

      const cacheKey = `${RECOMMENDED_FEEDS_CACHE_KEY}${userId}:${page}:${limit}:${shuffle}`;
      const cachedRecommendations = await redis.get(cacheKey);

      if (cachedRecommendations) {
        return res.json(JSON.parse(cachedRecommendations));
      }

      // Get user profile with interests and view history
      const userInterest = await UserInterest.findOne({ userId });
      const isNewUser = !userInterest || userInterest.recentViews.length < 5;
      
      // Get IDs of feeds the user has already viewed
      const viewedFeedIds = userInterest?.recentViews?.map(
        view => mongoose.Types.ObjectId(view.feedId)
      ) || [];
      
      let feeds = [];
      let totalFeeds = 0;
      let recommendationType = "";
      let recommendationStrategy = [];

      // 1. PERSONALIZED RECOMMENDATIONS (for returning users)
      if (!isNewUser && userInterest.interests.length > 0) {
        recommendationType = "personalized";
        recommendationStrategy.push("interest-based");

        // Calculate weighted interest scores (more recent = higher weight)
        const weightedInterests = userInterest.interests
          .map((interest) => ({
            tag: interest.tag,
            // Exponential decay based on time since last interaction
            score: interest.score * Math.exp(
              -((Date.now() - new Date(interest.lastInteraction)) / 
                (1000 * 60 * 60 * 24 * 14)) // Two-week half-life
            )
          }))
          .sort((a, b) => b.score - a.score);

        // Get top user interests (more if high engagement)
        const maxTags = userInterest.engagementLevel === "high" ? 10 : 
                        userInterest.engagementLevel === "medium" ? 7 : 5;
        const topTags = weightedInterests.slice(0, maxTags).map(i => i.tag);
        
        if (topTags.length > 0) {
          // Find feeds matching user's top interests, excluding viewed feeds
          const tagFeeds = await Feed.aggregate([
            {
              $match: {
                _id: { $nin: viewedFeedIds },
                content: {
                  $regex: new RegExp(
                    topTags.map(tag => `#${tag}`).join("|"),
                    "i"
                  )
                }
              }
            },
            {
              $addFields: {
                // Count how many of user's interests match this feed's tags
                matchingTags: {
                  $size: {
                    $setIntersection: [
                      topTags,
                      {
                        $map: {
                          input: {
                            $regexFindAll: { 
                              input: "$content", 
                              regex: /#(\w+)/g 
                            }
                          },
                          as: "tag",
                          in: { 
                            $toLower: { 
                              $substr: [
                                { $arrayElemAt: ["$$tag.match", 0] }, 
                                1, 
                                -1
                              ] 
                            } 
                          }
                        }
                      }
                    ]
                  }
                },
                // Calculate engagement score for ranking
                engagementScore: {
                  $add: [
                    { $ifNull: ["$views.count", 0] },
                    { $multiply: [{ $ifNull: ["$like.count", 0] }, 3] },
                    { $multiply: [{ $ifNull: ["$comment.count", 0] }, 5] }
                  ]
                },
                // Calculate recency score (newer = higher score)
                recencyScore: {
                  $divide: [
                    1,
                    { 
                      $add: [
                        1, 
                        { 
                          $divide: [
                            { $subtract: [new Date(), "$date"] },
                            1000 * 60 * 60 * 24 // Convert ms to days
                          ] 
                        }
                      ] 
                    }
                  ]
                }
              }
            },
            // Calculate combined relevance score
            {
              $addFields: {
                relevanceScore: {
                  $add: [
                    { $multiply: ["$matchingTags", 10] },
                    { $multiply: ["$engagementScore", 0.1] },
                    { $multiply: ["$recencyScore", 50] }
                  ]
                }
              }
            },
            { $sort: { relevanceScore: -1 } },
            { $skip: skip },
            { $limit: limit * 2 }, // Get more than needed for shuffling
            ...this.getCommonAggregationPipeline()
          ]);

          if (tagFeeds.length > 0) {
            feeds = tagFeeds;
            totalFeeds = await Feed.countDocuments({
              _id: { $nin: viewedFeedIds },
              content: {
                $regex: new RegExp(
                  topTags.map(tag => `#${tag}`).join("|"),
                  "i"
                )
              }
            });
          }
        }
      }

      // 2. LOCATION-BASED RECOMMENDATIONS
      // Try location-based if interest-based didn't return enough results and user has location
      if (feeds.length < limit && userInterest?.location?.latitude && userInterest?.location?.longitude) {
        recommendationType = feeds.length > 0 ? "mixed" : "location";
        recommendationStrategy.push("location-based");
        
        const { location } = userInterest;
        const hoursFromLocationUpdate = location.lastUpdated ? 
          Math.abs((new Date() - new Date(location.lastUpdated)) / (1000 * 60 * 60)) : 72;
        
        // Start with smaller radius for recent location, larger for older
        const initialRadius = hoursFromLocationUpdate < 24 ? 25 : 
                              hoursFromLocationUpdate < 72 ? 50 : 100;
                              
        // Try with increasing radius until we get enough results
        let radius = initialRadius;
        let locationFeeds = [];
        let locationTotalFeeds = 0;
        
        while (radius <= MAX_RADIUS_KM && locationFeeds.length < limit - feeds.length) {
          // Exclude feeds we've already added from interest-based recommendations
          const excludeIds = [...viewedFeedIds, ...feeds.map(f => f._id)];
          
          const locationResults = await this.getLocationBasedFeeds(
            location,
            excludeIds,
            radius,
            1, // Start from page 1
            limit - feeds.length, // Only get what we need
            0 // No skip for location-based
          );
          
          locationFeeds = locationResults.feeds;
          locationTotalFeeds = locationResults.totalFeeds;
          
          if (locationFeeds.length > 0) break;
          
          // Increase radius and try again
          radius *= 2;
        }
        
        if (locationFeeds.length > 0) {
          feeds = [...feeds, ...locationFeeds];
          totalFeeds += locationTotalFeeds;
        }
      }

      // 3. TRENDING/DISCOVERY RECOMMENDATIONS
      // If we still don't have enough feeds or user is new
      if (feeds.length < limit || isNewUser) {
        recommendationType = feeds.length > 0 ? "mixed" : (isNewUser ? "new-user" : "trending");
        recommendationStrategy.push("trending-discovery");
        
        // Exclude feeds we've already added from previous strategies
        const excludeIds = [...viewedFeedIds, ...feeds.map(f => f._id)];
        
        // For new users, focus more on popular content
        // For returning users with not enough recommendations, focus on discovery
        const popularityWeight = isNewUser ? 0.7 : 0.3;
        const recencyWeight = isNewUser ? 0.3 : 0.5;
        const randomnessWeight = isNewUser ? 0.0 : 0.2;
        
        const discoveryFeeds = await Feed.aggregate([
          {
            $match: {
              _id: { $nin: excludeIds }
            }
          },
          {
            $addFields: {
              // Calculate engagement score (popularity)
              popularityScore: {
                $add: [
                  { $ifNull: ["$views.count", 0] },
                  { $multiply: [{ $ifNull: ["$like.count", 0] }, 3] },
                  { $multiply: [{ $ifNull: ["$comment.count", 0] }, 5] }
                ]
              },
              // Calculate recency score
              recencyScore: {
                $divide: [
                  1,
                  { 
                    $add: [
                      1, 
                      { 
                        $divide: [
                          { $subtract: [new Date(), "$date"] },
                          1000 * 60 * 60 * 24 // Convert ms to days
                        ] 
                      }
                    ] 
                  }
                ]
              },
              // Add randomness factor
              randomFactor: { $rand: {} }
            }
          },
          {
            $addFields: {
              // Combined discovery score with weighted components
              discoveryScore: {
                $add: [
                  { $multiply: ["$popularityScore", popularityWeight] },
                  { $multiply: ["$recencyScore", 100 * recencyWeight] },
                  { $multiply: ["$randomFactor", 20 * randomnessWeight] }
                ]
              }
            }
          },
          { $sort: { discoveryScore: -1 } },
          { $skip: isNewUser ? 0 : skip }, // No skip for new users to get best content
          { $limit: isNewUser ? limit : (limit - feeds.length) },
          ...this.getCommonAggregationPipeline()
        ]);

        const discoveryTotalFeeds = await Feed.countDocuments({
          _id: { $nin: excludeIds }
        });
        
        if (discoveryFeeds.length > 0) {
          feeds = [...feeds, ...discoveryFeeds];
          totalFeeds += discoveryTotalFeeds;
        }
      }

      // Shuffle the feeds if requested (and we have more than needed)
      if (shuffle && feeds.length > limit) {
        // Fisher-Yates shuffle algorithm
        for (let i = feeds.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [feeds[i], feeds[j]] = [feeds[j], feeds[i]];
        }
        // Trim to requested limit
        feeds = feeds.slice(0, limit);
      }

      const result = {
        feeds,
        recommendationType,
        recommendationStrategy,
        pagination: {
          currentPage: page,
          totalPages: Math.ceil(totalFeeds / limit),
          totalFeeds,
          hasMore: page * limit < totalFeeds,
        },
        metadata: {
          isNewUser,
          timestamp: new Date(),
          shuffled: shuffle,
        }
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
