const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notification.controller');
const { optionalAuth } = require('../middleware/auth.middleware');

router.get('/', optionalAuth, notificationController.getNotifications);
router.get('/unread-count', optionalAuth, notificationController.getUnreadCount);
router.post('/mark-all-read', optionalAuth, notificationController.markAllAsRead);
router.put('/:id/read', optionalAuth, notificationController.markAsRead);
router.post('/:id/read', optionalAuth, notificationController.markAsRead);
router.delete('/:id', optionalAuth, notificationController.deleteNotification);
router.post('/test-push', optionalAuth, notificationController.testPushNotification);

module.exports = router;
