// controllers/serviceController.js
const Service = require('../model/Services');
const redisClient = require('../config/redis');

exports.createService = async (req, res) => {
    try {
        const { title, image, titleImage, description, priority } = req.body;

        // Create new service
        const service = new Service({
            title,
            image,
            titleImage,
            description,
            priority: priority 
        });

        // Save to database
        await service.save();

        // Cache the service
        await redisClient.setex(
            `service:${service._id}`, 
            3600, 
            JSON.stringify(service)
        );

        res.status(201).json({
            message: 'Service created successfully',
            service
        });
    } catch (error) {
        console.error('Error creating service:', error);
        res.status(500).json({
            message: 'Failed to create service',
            error: error.message
        });
    }
};

exports.getAllServices = async (req, res) => {
    try {
        const { page = 1, limit = 10 } = req.query;
        const skip = (page - 1) * limit;

        // Check cache first
        const cacheKey = `services:page:${page}:limit:${limit}`;
        const cachedServices = await redisClient.get(cacheKey);

        if (cachedServices) {
            return res.status(200).json(JSON.parse(cachedServices));
        }

        // If not in cache, fetch from database
        const services = await Service.find()
            .sort({ priority: -1 }) // Sort by priority
            .skip(Number(skip))
            .limit(Number(limit));

        const total = await Service.countDocuments();

        const result = {
            services,
            currentPage: Number(page),
            totalPages: Math.ceil(total / limit),
            totalServices: total
        };

        // Cache the result
        await redisClient.setex(
            cacheKey, 
            3600, 
            JSON.stringify(result)
        );

        res.status(200).json(result);
    } catch (error) {
        console.error('Error fetching services:', error);
        res.status(500).json({
            message: 'Failed to fetch services',
            error: error.message
        });
    }
};

exports.getServiceById = async (req, res) => {
    try {
        const { id } = req.params;

        // Check cache first
        const cachedService = await redisClient.get(`service:${id}`);
        
        if (cachedService) {
            return res.status(200).json(JSON.parse(cachedService));
        }

        // If not in cache, fetch from database
        const service = await Service.findById(id);

        if (!service) {
            return res.status(404).json({ message: 'Service not found' });
        }

        // Cache the service
        await redisClient.setex(
            `service:${id}`, 
            3600, 
            JSON.stringify(service)
        );

        res.status(200).json(service);
    } catch (error) {
        console.error('Error fetching service:', error);
        res.status(500).json({
            message: 'Failed to fetch service',
            error: error.message
        });
    }
};

exports.updateService = async (req, res) => {
    try {
        const { id } = req.params;
        const { title, image, titleImage, description, priority } = req.body;

        // Update service in database
        const service = await Service.findByIdAndUpdate(
            id, 
            {
                title,
                image,
                titleImage,
                description,
                priority: priority
            }, 
            { new: true }
        );

        if (!service) {
            return res.status(404).json({ message: 'Service not found' });
        }

        // Update cache
        await redisClient.setex(
            `service:${id}`, 
            3600, 
            JSON.stringify(service)
        );

        res.status(200).json({
            message: 'Service updated successfully',
            service
        });
    } catch (error) {
        console.error('Error updating service:', error);
        res.status(500).json({
            message: 'Failed to update service',
            error: error.message
        });
    }
};

exports.deleteService = async (req, res) => {
    try {
        const { id } = req.params;

        // Delete from database
        const service = await Service.findByIdAndDelete(id);

        if (!service) {
            return res.status(404).json({ message: 'Service not found' });
        }

        // Remove from cache
        await redisClient.del(`service:${id}`);

        res.status(200).json({
            message: 'Service deleted successfully'
        });
    } catch (error) {
        console.error('Error deleting service:', error);
        res.status(500).json({
            message: 'Failed to delete service',
            error: error.message
        });
    }
};