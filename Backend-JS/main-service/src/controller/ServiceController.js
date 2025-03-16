// controllers/serviceController.js
const Service = require('../model/Services');
const redisClient = require('../config/redis');

exports.createService = async (req, res) => {
    try {
        const { title, image, description, order } = req.body;
        
        const newService = new Service({
            title,
            image,
            description,
            order: order || 0
        });
        
        await newService.save();
        
        // Clear cache but don't fail if Redis is down
        try {
            await redisClient.del('all_services');
        } catch (error) {
            console.warn('Redis error when clearing services cache:', error.message);
        }
        
        res.status(201).json({
            success: true,
            message: 'Service created successfully',
            service: newService
        });
    } catch (error) {
        console.error('Error creating service:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to create service',
            error: error.message
        });
    }
};

exports.getAllServices = async (req, res) => {
    try {
        const cacheKey = 'all_services';
        
        // Try to get from cache but don't fail if Redis is down
        let cachedData = null;
        try {
            cachedData = await redisClient.get(cacheKey);
        } catch (error) {
            console.warn('Redis error when getting services:', error.message);
        }
        
        if (cachedData) {
            return res.status(200).json(JSON.parse(cachedData));
        }
        
        const services = await Service.find().sort({ order: 1 });
        
        // Cache for 1 hour but don't fail if Redis is down
        try {
            await redisClient.setex(cacheKey, 3600, JSON.stringify({
                success: true,
                message: 'Services fetched successfully',
                services
            }));
        } catch (error) {
            console.warn('Redis error when setting services cache:', error.message);
        }
        
        res.status(200).json({
            success: true,
            message: 'Services fetched successfully',
            services
        });
    } catch (error) {
        console.error('Error fetching services:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch services',
            error: error.message
        });
    }
};

exports.getServiceById = async (req, res) => {
    try {
        const { id } = req.params;
        const cacheKey = `service_${id}`;
        
        // Try to get from cache but don't fail if Redis is down
        let cachedData = null;
        try {
            cachedData = await redisClient.get(cacheKey);
        } catch (error) {
            console.warn(`Redis error when getting service ${id}:`, error.message);
        }
        
        if (cachedData) {
            return res.status(200).json(JSON.parse(cachedData));
        }
        
        const service = await Service.findById(id);
        
        if (!service) {
            return res.status(404).json({
                success: false,
                message: 'Service not found'
            });
        }
        
        // Cache for 1 hour but don't fail if Redis is down
        try {
            await redisClient.setex(
                cacheKey,
                3600,
                JSON.stringify({
                    success: true,
                    message: 'Service fetched successfully',
                    service
                })
            );
        } catch (error) {
            console.warn(`Redis error when setting service ${id} cache:`, error.message);
        }
        
        res.status(200).json({
            success: true,
            message: 'Service fetched successfully',
            service
        });
    } catch (error) {
        console.error('Error fetching service:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch service',
            error: error.message
        });
    }
};

exports.updateService = async (req, res) => {
    try {
        const { id } = req.params;
        const { title, image, description, order } = req.body;
        
        const updatedService = await Service.findByIdAndUpdate(
            id,
            { title, image, description, order },
            { new: true, runValidators: true }
        );
        
        if (!updatedService) {
            return res.status(404).json({
                success: false,
                message: 'Service not found'
            });
        }
        
        // Clear caches but don't fail if Redis is down
        try {
            await redisClient.del(`service_${id}`);
            await redisClient.del('all_services');
        } catch (error) {
            console.warn(`Redis error when clearing service caches:`, error.message);
        }
        
        res.status(200).json({
            success: true,
            message: 'Service updated successfully',
            service: updatedService
        });
    } catch (error) {
        console.error('Error updating service:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update service',
            error: error.message
        });
    }
};

exports.deleteService = async (req, res) => {
    try {
        const { id } = req.params;
        
        const service = await Service.findByIdAndDelete(id);
        
        if (!service) {
            return res.status(404).json({
                success: false,
                message: 'Service not found'
            });
        }
        
        // Clear caches but don't fail if Redis is down
        try {
            await redisClient.del(`service_${id}`);
            await redisClient.del('all_services');
        } catch (error) {
            console.warn(`Redis error when clearing service caches:`, error.message);
        }
        
        res.status(200).json({
            success: true,
            message: 'Service deleted successfully'
        });
    } catch (error) {
        console.error('Error deleting service:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to delete service',
            error: error.message
        });
    }
};