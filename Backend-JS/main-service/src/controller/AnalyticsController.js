const User = require("../model/User");
const GeoLocation = require("../model/Analytics/GeoLocation");
const axios = require("axios");

// Microservice URLs
const FEED_SERVICE_URL = process.env.FEED_SERVICE_URL || "http://localhost:3003";
const REEL_SERVICE_URL = process.env.REEL_SERVICE_URL || "http://localhost:3005";

exports.getDashboardStats = async (req, res) => {
  try {
    // Get timeframe from query params (default: week)
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
        startDate.setDate(startDate.getDate() - 7);
    }
    
    // Get user data from main service
    const [totalUsers, userTimeSeries, geoData] = await Promise.all([
      // Get total users
      User.countDocuments(),
      
      // Get user time series data
      User.aggregate([
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
      ]),
      
      // Get geolocation data
      GeoLocation.aggregate([
        {
          $match: {
            timestamp: { $gte: startDate }
          }
        },
        {
          $group: {
            _id: {
              country: "$country",
              latitude: "$latitude",
              longitude: "$longitude"
            },
            count: { $sum: 1 }
          }
        },
        {
          $project: {
            _id: 0,
            country: "$_id.country",
            latitude: "$_id.latitude",
            longitude: "$_id.longitude",
            count: 1
          }
        }
      ])
    ]);
    
    // Get data from feed and reel microservices
    let feedData = { totalFeeds: 0, feedTimeSeries: [], engagement: { totalLikes: 0, totalComments: 0 } };
    let reelData = { totalReels: 0, reelTimeSeries: [], engagement: { totalLikes: 0, totalComments: 0 } };
    
    try {
      // Fetch data from feed service
      const feedResponse = await axios.get(`${FEED_SERVICE_URL}/analytics/stats?timeframe=${timeframe}`);
      if (feedResponse.data && feedResponse.data.success) {
        feedData = feedResponse.data.data;
      }
    } catch (error) {
      console.error("Error fetching feed stats:", error.message);
    }
    
    try { 
      // Fetch data from reel service
      console.log("Reel service URL:", `${REEL_SERVICE_URL}/analytics/stats?timeframe=${timeframe}`);
      const reelResponse = await axios.get(`${REEL_SERVICE_URL}/analytics/stats?timeframe=${timeframe}`);
      if (reelResponse.data && reelResponse.data.success) {
        reelData = reelResponse.data.data;
      }
    } catch (error) {
      console.error("Error fetching reel stats:", error.message);
    }
    
    // Calculate mock revenue (this would be replaced with actual revenue data)
    const totalRevenue = 125000; // Mock value
    
    // Prepare response
    const response = {
      totals: {
        users: totalUsers,
        feeds: feedData.totalFeeds || 0,
        reels: reelData.totalReels || 0,
        revenue: totalRevenue
      },
      timeSeries: {
        users: userTimeSeries,
        feeds: feedData.feedTimeSeries || [],
        reels: reelData.reelTimeSeries || []
      },
      engagement: {
        feeds: feedData.engagement || { totalLikes: 0, totalComments: 0 },
        reels: reelData.engagement || { totalLikes: 0, totalComments: 0 }
      },
      topContent: {
        feeds: feedData.topFeeds || [],
        reels: reelData.topReels || []
      },
      geoData: geoData,
      timeframe
    };
    
    res.status(200).json({
      success: true,
      data: response
    });
  } catch (error) {
    console.error("Error fetching dashboard stats:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch dashboard statistics",
      error: error.message
    });
  }
};

exports.getGeoLocationData = async (req, res) => {
  try {
    const timeframe = req.query.timeframe || "week";
    let startDate = new Date();
    
    switch (timeframe) {
      case "today":
        startDate.setHours(0, 0, 0, 0);
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
        startDate.setDate(startDate.getDate() - 7);
    }
    
    const geoData = await GeoLocation.aggregate([
      {
        $match: {
          timestamp: { $gte: startDate }
        }
      },
      {
        $group: {
          _id: {
            country: "$country",
            latitude: "$latitude",
            longitude: "$longitude"
          },
          count: { $sum: 1 }
        }
      },
      {
        $project: {
          _id: 0,
          country: "$_id.country",
          latitude: "$_id.latitude",
          longitude: "$_id.longitude",
          count: 1
        }
      }
    ]);
    
    res.status(200).json({
      success: true,
      data: geoData,
      timeframe
    });
  } catch (error) {
    console.error("Error fetching geolocation data:", error);
    res.status(500).json({
      success: false,
      message: "Failed to fetch geolocation data",
      error: error.message
    });
  }
}; 