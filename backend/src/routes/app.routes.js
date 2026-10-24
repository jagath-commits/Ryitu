const express = require('express');
const router = express.Router();
const appController = require('../controllers/app.controller');

// Public endpoint for mobile apps to check version requirements
router.get('/version', appController.getVersion);

// Admin / management endpoint to update version requirements
router.post('/version', appController.updateVersion);

module.exports = router;
