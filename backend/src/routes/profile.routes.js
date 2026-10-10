const express = require('express');
const router = express.Router();
const profileController = require('../controllers/profile.controller');
const { optionalAuth } = require('../middleware/auth.middleware');
const { uploadProfileImage } = require('../middleware/upload.middleware');

router.get('/profile/:userId', optionalAuth, profileController.getProfile);
router.post('/update', optionalAuth, uploadProfileImage, profileController.updateProfile);

module.exports = router;
