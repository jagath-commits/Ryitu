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
  limits: { fileSize: env.MAX_FILE_SIZE },
  fileFilter: (req, file, cb) => {
    const isPdf = file.mimetype === 'application/pdf' || path.extname(file.originalname).toLowerCase() === '.pdf';
    if (isPdf) cb(null, true);
    else cb(new Error('Only PDF documents are allowed.'), false);
  }
}).single('pdf');

const uploadDocument = multer({
  storage: documentStorage,
  limits: { fileSize: env.MAX_FILE_SIZE, fieldSize: 100 * 1024 * 1024 }
}).single('document');

const uploadProfileImage = multer({
  storage: profileStorage,
  limits: { fileSize: 20 * 1024 * 1024 }
}).single('profile_image');

const uploadPostFiles = multer({
  storage: postStorage,
  limits: { fileSize: env.MAX_FILE_SIZE, fieldSize: 100 * 1024 * 1024 }
}).fields([
  { name: 'cover_image', maxCount: 1 },
  { name: 'page_images', maxCount: 5000 }
]);

module.exports = {
  uploadPdf,
  uploadDocument,
  uploadProfileImage,
  uploadPostFiles
};