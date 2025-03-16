const { v2 } = require("cloudinary")

// Get configuration from environment variables
v2.config({ 
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME || "dkemrlxyt", 
    api_key: process.env.CLOUDINARY_API_KEY || "928577748254365",
    api_secret: process.env.CLOUDINARY_API_SECRET || "G3uGJh44Jvm6L9txpS4v67wwGEY" 
});

module.exports = v2; 
