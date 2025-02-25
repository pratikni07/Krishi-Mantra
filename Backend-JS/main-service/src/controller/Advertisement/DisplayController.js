const UIDisplay = require('../../model/UIModel/UIDisplay');
const HomeSlider = require('../../model/UIModel/HomeScreen/HomeSliderModel');
const NewsAds = require('../../model/UIModel/NewsScreen/NewsAds');
const SplashModal = require('../../model/UIModel/HomeScreen/SplashModel');
const RedisClient = require('../../config/redis');

class DisplayController {
    async getDynamicDisplay(req, res) {
        try {
            const cachedDisplay = await RedisClient.get('dynamic_display');
            if (cachedDisplay) {
                return res.json(JSON.parse(cachedDisplay));
            }
            const displaySettings = await UIDisplay.findOne();

            const dynamicContent = {
                displaySettings: displaySettings || {},
                homeSlider: displaySettings?.Slider ? await HomeSlider.find().sort({ prority: -1 }) : [],
                splashScreen: displaySettings?.SplashScreen ? await SplashModal.findOne({ prority: true }) : null,
                homeScreenAds: displaySettings?.HomeScreenAdOne ? await HomeSlider.findOne() : null,
                  
                feedAds: displaySettings?.FeedAds ? await NewsAds.find() : [],
                reelAds: displaySettings?.ReelAds ? await NewsAds.find() : [],
                newsAds: displaySettings?.NewsAds ? await NewsAds.find() : []
            };

            // Cache the result
            await RedisClient.setex('dynamic_display', 3600, JSON.stringify(dynamicContent),JSON.stringify(displaySettings)); 

            return res.status(200).json({
                success: true,
                displaySettings,
                dynamicContent,
                message: "dynamic_display",
            });
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    }

    // Update Display Settings
    async updateDisplaySettings(req, res) {
        try {
            const updateData = req.body;
            
            // Find existing settings or create new
            let displaySettings = await UIDisplay.findOne();
            
            if (displaySettings) {
                displaySettings = await UIDisplay.findOneAndUpdate({}, updateData, { new: true });
            } else {
                displaySettings = new UIDisplay(updateData);
                await displaySettings.save();
            }

            // Clear dynamic display cache
            await RedisClient.del('dynamic_display');

            res.json(displaySettings);
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    }
}

module.exports = new DisplayController();