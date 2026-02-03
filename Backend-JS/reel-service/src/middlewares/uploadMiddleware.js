const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Ensure upload directory exists
const uploadDir = path.join(__dirname, '../../uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Allowed video MIME types
const ALLOWED_VIDEO_TYPES = [
  'video/mp4',
  'video/quicktime', // .mov
  'video/x-msvideo', // .avi
  'video/webm',
  'video/x-matroska', // .mkv
  'video/3gpp', // .3gp
];

// Allowed image MIME types (for thumbnails)
const ALLOWED_IMAGE_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
];

// Configure storage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    const ext = path.extname(file.originalname);
    cb(null, `${file.fieldname}-${uniqueSuffix}${ext}`);
  },
});

// File filter for videos
const videoFilter = (req, file, cb) => {
  if (ALLOWED_VIDEO_TYPES.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(
      new Error(`Invalid file type. Allowed types: ${ALLOWED_VIDEO_TYPES.join(', ')}`),
      false
    );
  }
};

// File filter for images
const imageFilter = (req, file, cb) => {
  if (ALLOWED_IMAGE_TYPES.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(
      new Error(`Invalid file type. Allowed types: ${ALLOWED_IMAGE_TYPES.join(', ')}`),
      false
    );
  }
};

// Video upload configuration
// Max file size: 100MB for reels
const videoUpload = multer({
  storage,
  fileFilter: videoFilter,
  limits: {
    fileSize: 100 * 1024 * 1024, // 100MB
    files: 1,
  },
});

// Image upload configuration
// Max file size: 10MB for thumbnails
const imageUpload = multer({
  storage,
  fileFilter: imageFilter,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
    files: 1,
  },
});

// Combined upload for video + thumbnail
const reelUpload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    if (file.fieldname === 'video') {
      videoFilter(req, file, cb);
    } else if (file.fieldname === 'thumbnail') {
      imageFilter(req, file, cb);
    } else {
      cb(new Error('Unexpected field'), false);
    }
  },
  limits: {
    fileSize: 100 * 1024 * 1024, // 100MB total
    files: 2,
  },
});

// Error handler middleware
const handleMulterError = (err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        status: 'error',
        message: 'File too large. Maximum size is 100MB for videos, 10MB for images.',
      });
    }
    if (err.code === 'LIMIT_FILE_COUNT') {
      return res.status(400).json({
        status: 'error',
        message: 'Too many files. Maximum is 1 video and 1 thumbnail.',
      });
    }
    return res.status(400).json({
      status: 'error',
      message: err.message,
    });
  }

  if (err) {
    return res.status(400).json({
      status: 'error',
      message: err.message,
    });
  }

  next();
};

module.exports = {
  videoUpload,
  imageUpload,
  reelUpload,
  handleMulterError,
  uploadDir,
};
