const express = require('express');
const router = express.Router();
const draftController = require('../controllers/draft.controller');
const { optionalAuth } = require('../middleware/auth.middleware');
const { uploadPostFiles } = require('../middleware/upload.middleware');

const postController = require('../controllers/post.controller');

router.post('/saveDraft', optionalAuth, uploadPostFiles, draftController.saveDraft);
router.get('/getdraftposts/:userId', optionalAuth, postController.getUserDrafts);
router.get('/draftposts/:userId', optionalAuth, postController.getUserDrafts);
router.get('/:userId', optionalAuth, postController.getUserDrafts);
router.delete('/:id', optionalAuth, draftController.deleteDraft);

module.exports = router;
