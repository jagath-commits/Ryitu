const express = require('express');
const router = express.Router();
const communityController = require('../controllers/community.controller');
const { optionalAuth } = require('../middleware/auth.middleware');
const { uploadCommunityImage } = require('../middleware/upload.middleware');

router.get('/', optionalAuth, communityController.getCommunities);
router.post('/', optionalAuth, uploadCommunityImage, communityController.createCommunity);
router.get('/my-communities', optionalAuth, communityController.getMyCommunities);
router.get('/:communityId', optionalAuth, communityController.getCommunityById);
router.get('/:communityId/posts', optionalAuth, communityController.getCommunityPosts);
router.post('/:communityId/request-join', optionalAuth, communityController.requestJoin);
router.get('/:communityId/membership-status', optionalAuth, communityController.getMembershipStatus);
router.get('/:communityId/available-users', optionalAuth, communityController.getAvailableUsers);
router.post('/:communityId/members', optionalAuth, communityController.addMembers);
router.get('/:communityId/join-requests', optionalAuth, communityController.getJoinRequests);
router.post('/:communityId/join-requests/:requestId/action', optionalAuth, communityController.handleJoinRequestAction);
router.post('/:communityId/join-requests/action', optionalAuth, communityController.handleJoinRequestAction);

module.exports = router;

