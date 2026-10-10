const express = require('express');
const router = express.Router({ mergeParams: true });
const bookmarkController = require('../controllers/bookmark.controller');
const { optionalAuth } = require('../middleware/auth.middleware');

router.use(optionalAuth);

router.post('/', bookmarkController.addBookmark);
router.get('/', bookmarkController.getBookmarks);
router.delete('/:bookmarkId', bookmarkController.deleteBookmark);

module.exports = router;