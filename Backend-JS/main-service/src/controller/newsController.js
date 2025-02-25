const News = require("../model/News");
const redisClient = require("../config/redis");
const cloudinary = require("../config/cloudinary");
const mongoose = require("mongoose");

class NewsController {
    async createNews(req, res) {
        try {
            const { content, tags,imageUrl } = req.body;
            const uploadedBy = req.user._id;

            const news = new News({
                content,
                tags,
                uploadedBy,
                image: imageUrl
            });

            await news.save();

            // Invalidate news cache
            await redisClient.del("news:all");

            res.status(201).json({
                success: true,
                data: news
            });
        } catch (error) {
            res.status(400).json({
                success: false,
                message: error.message
            });
        }
    }

    // Get All News with Caching
    async getAllNews(req, res) {
        try {
            const page = parseInt(req.query.page) || 1;
            const limit = parseInt(req.query.limit) || 10;
            const skip = (page - 1) * limit;

            // Check Redis cache first
            const cacheKey = `news:all:page:${page}:limit:${limit}`;
            const cachedNews = await redisClient.get(cacheKey);

            if (cachedNews) {
                return res.status(200).json(JSON.parse(cachedNews));
            }

            const news = await News.find({ isPublished: true })
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(limit)
                .populate('uploadedBy', 'name');

            const total = await News.countDocuments({ isPublished: true });

            const response = {
                success: true,
                count: news.length,
                total,
                page,
                totalPages: Math.ceil(total / limit),
                data: news
            };

            // Cache the result
            await redisClient.setex(cacheKey, 3600, JSON.stringify(response));

            res.status(200).json(response);
        } catch (error) {
            res.status(500).json({
                success: false,
                message: error.message
            });
        }
    }

    // Like a News
    async likeNews(req, res) {
        try {
            const { id } = req.params;
            const userId = req.user._id;

            const news = await News.findById(id);
            if (!news) {
                return res.status(404).json({
                    success: false,
                    message: "News not found"
                });
            }

            // Use atomic operation to prevent race conditions
            const updatedNews = await News.findByIdAndUpdate(
                id, 
                { 
                    $inc: { likes: 1 },
                    $addToSet: { likedBy: userId }
                },
                { new: true }
            );

            // Invalidate cache
            await redisClient.del(`news:${id}`);
            await redisClient.del("news:all");

            res.status(200).json({
                success: true,
                data: updatedNews
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                message: error.message
            });
        }
    }

    // Search News
    async searchNews(req, res) {
        try {
            const { query, tags } = req.query;
            const page = parseInt(req.query.page) || 1;
            const limit = parseInt(req.query.limit) || 10;
            const skip = (page - 1) * limit;

            let searchCriteria = { isPublished: true };

            if (query) {
                searchCriteria.$text = { $search: query };
            }

            if (tags) {
                searchCriteria.tags = { $in: tags.split(',') };
            }

            const news = await News.find(searchCriteria)
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(limit)
                .populate('uploadedBy', 'name');

            const total = await News.countDocuments(searchCriteria);

            res.status(200).json({
                success: true,
                count: news.length,
                total,
                page,
                totalPages: Math.ceil(total / limit),
                data: news
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                message: error.message
            });
        }
    }
}

module.exports = new NewsController();