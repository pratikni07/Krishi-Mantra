const Feed = require("../model/FeedModel");
const Comment = require("../model/CommetModel");
const Like = require("../model/LikeModel");

exports.getFeedStats = async (req, res) => {
  try {
    // Get timeframe from query params
    const timeframe = req.query.timeframe || "week";
    
    // Calculate date range based on timeframe
    const endDate = new Date();
    let startDate = new Date();
    
    switch (timeframe) {
      case "day":
        startDate.setDate(startDate.getDate() - 1);
        break;
      case "week":
        startDate.setDate(startDate.getDate() - 7);
        break;
      case "month":
        startDate.setMonth(startDate.getMonth() - 1);
        break;
      case "year":
        startDate.setFullYear(startDate.getFullYear() - 1);
        break;
      default:
        startDate.setDate(startDate.getDate() - 7); // Default to week
    }
    
    // Get total feeds count
    const totalFeeds = await Feed.countDocuments();
    
    // Get time-series data for feeds created
    const feedTimeSeries = await Feed.aggregate([
      {
        $match: {
          createdAt: { $gte: startDate, $lte: endDate }
        }
      },
      {
        $group: {
          _id: { 
            $dateToString: { 
              format: timeframe === "year" ? "%Y-%m" : "%Y-%m-%d", 
              date: "$createdAt" 
            } 
          },
          count: { $sum: 1 }
        }
      },
      { $sort: { _id: 1 } }
    ]);
    
    // Get engagement stats
    const totalLikes = await Like.countDocuments();
    let totalComments = 0;
    try {
      totalComments = await Comment.countDocuments();
    } catch (error) {
      console.log("Comment model not available or other error:", error.message);
    }
    
    // Get top feeds by engagement
    const topFeeds = await Feed.aggregate([
      {
        $project: {
          content: 1,
          userName: 1,
          mediaUrls: 1,
          likeCount: { $ifNull: ["$like.count", 0] },
          commentCount: { $ifNull: ["$comment.count", 0] },
          engagement: { 
            $add: [
              { $ifNull: ["$like.count", 0] },
              { $ifNull: ["$comment.count", 0] }
            ]
          },
          createdAt: 1
        }
      },
      { $sort: { engagement: -1 } },
      { $limit: 5 }
    ]);
    
    res.status(200).json({
      success: true,
      data: {
        totalFeeds,
        feedTimeSeries,
        engagement: {
          totalLikes,
          totalComments,
          averagePerFeed: totalFeeds > 0 ? (totalLikes + totalComments) / totalFeeds : 0
        },
        topFeeds
      }
    });
  } catch (error) {
    console.error("Error fetching feed stats:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch feed statistics",
      error: error.message
    });
  }
}; 