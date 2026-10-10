const express = require('express');
const router = express.Router({ mergeParams: true });
const progressController = require('../controllers/progress.controller');
const { optionalAuth } = require('../middleware/auth.middleware');

router.use(optionalAuth);

router.get('/', progressController.getProgress);
router.put('/', progressController.updateProgress);

module.exports = router;