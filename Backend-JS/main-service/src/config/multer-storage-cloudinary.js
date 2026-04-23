const multer = require('multer');
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const cloudinary = require('../config/cloudinary');

const ALLOWED_IMAGE_MIMES = new Set([
  'image/jpeg',
  'image/pjpeg',
  'image/png',
  'image/webp',
]);

const storage = new CloudinaryStorage({
    cloudinary,
    params: {
        folder: 'home_ads',
        // Cloudinary rejects formats outside this list server-side; acts
        // as the second layer after the MIME filter below.
        allowed_formats: ['jpg', 'jpeg', 'png'],
    },
});

// MIME-level pre-filter. Cheap first check so we don't stream the full
// upload to Cloudinary just to have it bounce; Cloudinary then enforces
// the real format check. Can't do magic-bytes before streaming starts
// because CloudinaryStorage handles bytes directly, so we rely on
// Cloudinary's post-upload validation as the authoritative check.
const fileFilter = (_req, file, cb) => {
  if (ALLOWED_IMAGE_MIMES.has(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Only JPEG / PNG / WebP images are allowed.'), false);
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10 MB per file
    files: 5,
  },
});

module.exports = upload;
