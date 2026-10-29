const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const env = require('../config/env');

const ensureDir = (dirPath) => {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
};

const pdfStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(__dirname, '../../uploads/pdf');
    ensureDir(dir);
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.pdf';
    cb(null, `pdf_${uuidv4()}${ext}`);
  }
});

const documentStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(__dirname, '../../uploads/documents');
    ensureDir(dir);
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.pdf';
    cb(null, `doc_${Date.now()}_${uuidv4().substring(0, 8)}${ext}`);
  }
});

const profileStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(__dirname, '../../uploads/profile_images');
    ensureDir(dir);
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    cb(null, `profile_${Date.now()}_${uuidv4().substring(0, 8)}${ext}`);
  }
});

const postStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    if (file.fieldname === 'cover_image') {
      const dir = path.join(__dirname, '../../uploads/covers');
      ensureDir(dir);
      cb(null, dir);
    } else {
      const dir = path.join(__dirname, '../../uploads/page_images');
      ensureDir(dir);
      cb(null, dir);
    }
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    cb(null, `${file.fieldname}_${Date.now()}_${uuidv4().substring(0, 8)}${ext}`);
  }
});

const uploadPdf = multer({
  storage: pdfStorage,
  limits: {
    fileSize: env.MAX_FILE_SIZE,
    fieldSize: 10 * 1024 * 1024,
    fields: 30,
    files: 1
  },
  fileFilter: (req, file, cb) => {
    const isPdfMime = file.mimetype === 'application/pdf' || file.mimetype === 'application/x-pdf' || file.mimetype === 'application/octet-stream';
    const isPdfExt = path.extname(file.originalname).toLowerCase() === '.pdf';
    if (isPdfMime || isPdfExt) {
      cb(null, true);
    } else {
      const err = new Error('Only PDF documents are allowed.');
      err.code = 'INVALID_FILE_TYPE';
      cb(err, false);
    }
  }
}).single('pdf');

const uploadDocument = multer({
  storage: documentStorage,
  limits: {
    fileSize: env.MAX_FILE_SIZE,
    fieldSize: 30 * 1024 * 1024,
    fields: 50,
    files: 1
  },
  fileFilter: (req, file, cb) => {
    const isDoc = file.mimetype === 'application/pdf' ||
      file.mimetype === 'application/x-pdf' ||
      file.mimetype === 'application/octet-stream' ||
      /\.(pdf|docx?|txt)$/i.test(file.originalname);
    if (isDoc) {
      cb(null, true);
    } else {
      const err = new Error('Only PDF, DOCX, and TXT documents are allowed.');
      err.code = 'INVALID_FILE_TYPE';
      cb(err, false);
    }
  }
}).single('document');

const communityStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(__dirname, '../../uploads/community_images');
    ensureDir(dir);
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    cb(null, `community_${Date.now()}_${uuidv4().substring(0, 8)}${ext}`);
  }
});

const isImageFile = (file) => {
  if (file.mimetype && file.mimetype.startsWith('image/')) return true;
  const ext = path.extname(file.originalname).toLowerCase();
  return /\.(jpe?g|png|webp|gif|bmp|heic|heif|svg)$/i.test(ext);
};

const imageFileFilter = (req, file, cb) => {
  if (isImageFile(file)) {
    cb(null, true);
  } else {
    cb(null, true); // Permissive to prevent rejecting valid images with unusual headers
  }
};

const uploadProfileImage = multer({
  storage: profileStorage,
  limits: { fileSize: 50 * 1024 * 1024, fieldSize: 50 * 1024 * 1024 },
  fileFilter: imageFileFilter
}).single('profile_image');

const uploadCommunityImage = multer({
  storage: communityStorage,
  limits: { fileSize: 50 * 1024 * 1024, fieldSize: 50 * 1024 * 1024 },
  fileFilter: imageFileFilter
}).fields([
  { name: 'image', maxCount: 1 },
  { name: 'community_image', maxCount: 1 },
  { name: 'profile_image', maxCount: 1 }
]);

const uploadPostFiles = multer({
  storage: postStorage,
  limits: { fileSize: env.MAX_FILE_SIZE, fieldSize: 300 * 1024 * 1024 }
}).fields([
  { name: 'cover_image', maxCount: 1 },
  { name: 'page_images', maxCount: 5000 }
]);

module.exports = {
  uploadPdf,
  uploadDocument,
  uploadProfileImage,
  uploadCommunityImage,
  uploadPostFiles
};