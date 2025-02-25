const multer = require('multer');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const cloudinary = require('../config/cloudinary'); // Your Cloudinary configuration file

const storage = new CloudinaryStorage({
    cloudinary,
    params: {
        folder: 'home_ads',
        allowed_formats: ['jpg', 'jpeg', 'png'], // Adjust allowed formats
    },
});

const upload = multer({ storage });

module.exports = upload;
