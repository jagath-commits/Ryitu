const express = require('express');
const router = express.Router();
const communityController = require('../controllers/community.controller');
const { optionalAuth } = require('../middleware/auth.middleware');

router.get('/', optionalAuth, communityController.getCommunities);
router.post('/', optionalAuth, communityController.createCommunity);
router.get('/my-communities', optionalAuth, communityController.getMyCommunities);
router.get('/:communityId', optionalAuth, communityController.getCommunityById);
router.get('/:communityId/posts', optionalAuth, communityController.getCommunityPosts);
router.post('/:communityId/request-join', optionalAuth, communityController.requestJoin);
router.get('/:communityId/membership-status', optionalAuth, communityController.getMembershipStatus);
router.get('/:communityId/available-users', optionalAuth, communityController.getAvailableUsers);
router.post('/:communityId/members', optionalAuth, communityController.addMembers);

module.exports = router;

