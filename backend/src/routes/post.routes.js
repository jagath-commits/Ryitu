const express = require('express');
const router = express.Router();
const postController = require('../controllers/post.controller');
const { optionalAuth } = require('../middleware/auth.middleware');
const { uploadDocument, uploadPostFiles } = require('../middleware/upload.middleware');

// PDF / Document extraction routes
router.post('/extractDocument', optionalAuth, uploadDocument, postController.extractDocument);
router.get('/documentFull/:extractionId', postController.getDocumentFull);
router.get('/documentChunk/:extractionId/:chunkIndex', postController.getDocumentChunk);

// User-specific collections
router.get('/userposts/:userId', optionalAuth, postController.getUserPosts);
router.get('/savedposts/:userId', optionalAuth, postController.getSavedPosts);
router.get('/getdraftposts/:userId', optionalAuth, postController.getUserDrafts);
router.get('/draftposts/:userId', optionalAuth, postController.getUserDrafts);

// Post interactions
router.post('/toggleSupport/:id', optionalAuth, postController.toggleSupport);
router.post('/toggleSave/:id', optionalAuth, postController.toggleSave);
router.post('/view/:id', postController.incrementView);

// Comments routes
router.get('/:postId/comments', optionalAuth, postController.getComments);
router.post('/:postId/comments', optionalAuth, postController.addComment);
router.post('/comments/:commentId/toggleLike', optionalAuth, postController.toggleCommentLike);
router.delete('/comments/:commentId', optionalAuth, postController.deleteComment);

// Standard Post CRUD
router.get('/', postController.getPosts);
router.post('/', optionalAuth, uploadPostFiles, postController.createPost);
router.get('/:id', postController.getPostById);
router.delete('/:id', optionalAuth, postController.deletePost);

module.exports = router;
