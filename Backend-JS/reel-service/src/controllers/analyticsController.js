const Reel = require("../models/Reel");
const Comment = require("../models/CommentModal");
const Like = require("../models/LikeModel");

exports.getReelStats = async (req, res) => {
  try {
    // Get timeframe from query params
    console.log("Request query:", req.query);
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
    
    // Get total reels count
    const totalReels = await Reel.countDocuments();
    
    // Get time-series data for reels created
    const reelTimeSeries = await Reel.aggregate([
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
    
    // Get total comments if Comment model exists
    let totalComments = 0;
    try {
      totalComments = await Comment.countDocuments();
    } catch (error) {
      console.log("Comment model not available or other error:", error.message);
    }
    
    // Get top reels by engagement
    const topReels = await Reel.aggregate([
      {
        $project: {
          description: 1,
          userName: 1,
          mediaUrl: 1,
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
        totalReels,
        reelTimeSeries,
        engagement: {
          totalLikes,
          totalComments,
          averagePerReel: totalReels > 0 ? (totalLikes + totalComments) / totalReels : 0
        },
        topReels
      }
    });
  } catch (error) {
    console.error("Error fetching reel stats:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch reel statistics",
      error: error.message
    });
  }
}; 