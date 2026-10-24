const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '../../.env') });

module.exports = {
  PORT: process.env.PORT || 5000,
  MONGODB_URI: process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/pdf_book_reader',
  JWT_SECRET: process.env.JWT_SECRET || 'pdf_reader_secret_key_change_in_production',
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '7d',
  UPLOAD_DIR: process.env.UPLOAD_DIR || 'uploads',
  MAX_FILE_SIZE: parseInt(process.env.MAX_FILE_SIZE, 10) || 250 * 1024 * 1024, // 250MB
  BASE_URL: process.env.BASE_URL || 'http://localhost:5000',
  NODE_ENV: process.env.NODE_ENV || 'development',
  EMAIL_USER: process.env.EMAIL_USER || '',
  EMAIL_PASS: process.env.EMAIL_PASS || '',
  EMAIL_FROM: process.env.EMAIL_FROM || '',

  // App Version & Forced Update Settings
  APP_MIN_BUILD_NUMBER: parseInt(process.env.APP_MIN_BUILD_NUMBER, 10) || 7,
  APP_LATEST_BUILD_NUMBER: parseInt(process.env.APP_LATEST_BUILD_NUMBER, 10) || 7,
  APP_MIN_VERSION: process.env.APP_MIN_VERSION || '1.0.5',
  APP_LATEST_VERSION: process.env.APP_LATEST_VERSION || '1.0.5',
  APP_FORCE_UPDATE: process.env.APP_FORCE_UPDATE !== 'false',
  APP_UPDATE_URL: process.env.APP_UPDATE_URL || 'https://play.google.com/store/apps/details?id=com.ritpen',
  APP_UPDATE_TITLE: process.env.APP_UPDATE_TITLE || 'Update Required',
  APP_UPDATE_MESSAGE:
    process.env.APP_UPDATE_MESSAGE ||
    'A new version of Ritpen is available with important improvements and bug fixes. Please update the app to continue.'
};

