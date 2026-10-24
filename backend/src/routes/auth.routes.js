const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { uploadProfileImage } = require('../middleware/upload.middleware');

router.post('/register', uploadProfileImage, authController.register);
router.post('/check-mobile', authController.checkMobile);
router.post('/login', authController.login);
router.post('/save-fcm-token', authController.saveFcmToken);
router.post('/forgot-password', authController.forgotPassword);
router.post('/forgot-password/send-otp', authController.sendOtp);
router.post('/forgot-password/verify-otp', authController.verifyOtp);
router.post('/forgot-password/reset-password', authController.resetPassword);
router.get('/me', authenticate, authController.getMe);

module.exports = router;