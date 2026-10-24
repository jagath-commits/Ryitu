const mongoose = require('mongoose');
const Community = require('../models/Community');
const CommunityMember = require('../models/CommunityMember');
const Post = require('../models/Post');
const { successResponse, errorResponse } = require('../utils/response.util');

const User = require('../models/User');
const notificationService = require('../services/notification.service');

// Helper to seed sample communities if empty
const seedSampleCommunitiesIfNeeded = async () => {
  try {
    const count = await Community.countDocuments();
    if (count === 0) {
      const c1 = await Community.create({
        name: 'Ryitu Farmers & Agriculture',
        description: 'A thriving community dedicated to sustainable farming practices, modern agricultural techniques, organic cultivation, and farmers welfare.',
        image: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?auto=format&fit=crop&w=500&q=80',
        coverImage: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?auto=format&fit=crop&w=1200&q=80',
        memberCount: 142
      });

      const c2 = await Community.create({
        name: 'Tamil Literature & History',
        description: 'Preserving, discussing and reading ancient Sangam literature, historical fiction, epic poetry, and cultural heritage.',
        image: 'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?auto=format&fit=crop&w=500&q=80',
        coverImage: 'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?auto=format&fit=crop&w=1200&q=80',
        memberCount: 98
      });

      const c3 = await Community.create({
        name: 'Science, Tech & Digital Research',
        description: 'Open library and discussion forum for software engineering, artificial intelligence, robotics, and scientific publications.',
        image: 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=500&q=80',
        coverImage: 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1200&q=80',
        memberCount: 76
      });

      // Also create sample community posts so Feed displays both General and Community Posts right away
      await Post.create([
        {
          title: 'Modern Drip Irrigation Systems Guide',
          caption: 'Comprehensive handbook on water-saving irrigation technology for crop yield maximization.',
          user_id: 'USR00000001',
          username: 'Kavitha Farmer',
          communityId: c1._id.toString(),
          communityName: c1.name,
          category: 'Ryitu',
          categoryId: 'CAT00000004',
          cover_image: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?auto=format&fit=crop&w=600&q=80',
          cover_img: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?auto=format&fit=crop&w=600&q=80',
          coverImage: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?auto=format&fit=crop&w=600&q=80',
          hashtags: '#agriculture #drip #farming',
          content: [
            {
              blocks: [
                { type: 'text', text: 'Drip irrigation delivers water directly to plant roots, minimizing evaporation and weed growth.' }
              ]
            }
          ]
        },
        {
          title: 'Ponniyin Selvan: Heritage Context and Architecture',
          caption: 'Detailed architectural and cultural analysis of the Chola Empire in Kalki novels.',
          user_id: 'USR00000001',
          username: 'Selvakumar Historian',
          communityId: c2._id.toString(),
          communityName: c2.name,
          category: 'Ryitu',
          categoryId: 'CAT00000004',
          cover_image: 'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?auto=format&fit=crop&w=600&q=80',
          cover_img: 'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?auto=format&fit=crop&w=600&q=80',
          coverImage: 'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?auto=format&fit=crop&w=600&q=80',
          hashtags: '#heritage #literature #chola',
          content: [
            {
              blocks: [
                { type: 'text', text: 'The Brihadisvara Temple reflects the monumental engineering prowess of the imperial Cholas.' }
              ]
            }
          ]
        }
      ]);
    }
  } catch (err) {
    console.warn('[Community Seed] Non-fatal seed error:', err.message);
  }
};

// 1. List Communities
const getCommunities = async (req, res, next) => {
  try {
    await seedSampleCommunitiesIfNeeded();
    const communities = await Community.find().sort({ createdAt: -1 });
    return successResponse(res, 200, 'Communities fetched successfully', {
      count: communities.length,
      communities
    });
  } catch (error) {
    next(error);
  }
};

// 1b. Create Community
const createCommunity = async (req, res, next) => {
  try {
    const { name, description, image, coverImage } = req.body;
    const userId = req.user ? req.user._id : (req.body.userId || req.body.creatorId || req.body.user_id || 'USR00000001');

    if (!name || !name.trim()) {
      return errorResponse(res, 400, 'Community name is required');
    }

    let uploadedFilename = '';
    if (req.file) {
      uploadedFilename = req.file.filename;
    } else if (req.files) {
      const file = (req.files.image && req.files.image[0]) ||
                   (req.files.community_image && req.files.community_image[0]) ||
                   (req.files.profile_image && req.files.profile_image[0]);
      if (file) uploadedFilename = file.filename;
    }

    let finalImage = '';
    if (uploadedFilename) {
      finalImage = `${req.protocol}://${req.get('host')}/uploads/community_images/${uploadedFilename}`;
    } else if (image && image.trim()) {
      finalImage = image.trim();
    } else {
      finalImage = 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=600&q=80';
    }

    const defaultCover = (coverImage && coverImage.trim()) || finalImage;

    const community = await Community.create({
      name: name.trim(),
      description: description ? description.trim() : '',
      image: finalImage,
      coverImage: defaultCover,
      creatorId: userId.toString(),
      memberCount: 1
    });

    // Automatically make creator an approved joined member
    await CommunityMember.findOneAndUpdate(
      { communityId: community._id.toString(), userId: userId.toString() },
      {
        communityId: community._id.toString(),
        userId: userId.toString(),
        status: 'joined',
        approvedAt: new Date()
      },
      { upsert: true, new: true }
    );

    return successResponse(res, 201, 'Community created successfully', {
      community: {
        ...community.toObject(),
        joinStatus: 'joined',
        isMember: true,
        isCreator: true
      }
    });
  } catch (error) {
    next(error);
  }
};

// 1c. Get My Joined/Created Communities (Separated by Created and Joined)
const getMyCommunities = async (req, res, next) => {
  try {
    await seedSampleCommunitiesIfNeeded();
    const userId = req.user ? req.user._id : (req.query.userId || req.query.user_id || 'USR00000001');
    const uStr = userId ? userId.toString() : 'USR00000001';

    const userIds = [uStr];
    if (req.user && req.user.user_id && req.user.user_id !== uStr) {
      userIds.push(req.user.user_id.toString());
    }
    if (req.user && req.user._id && req.user._id.toString() !== uStr) {
      userIds.push(req.user._id.toString());
    }

    // 1. Fetch communities created by the authenticated user
    const createdRaw = await Community.find({
      creatorId: { $in: userIds }
    }).sort({ createdAt: -1 });

    const createdCommunities = [];
    for (const c of createdRaw) {
      const commObj = c.toObject();
      const pendingCount = await CommunityMember.countDocuments({
        communityId: c._id.toString(),
        status: 'pending'
      });
      createdCommunities.push({
        ...commObj,
        joinStatus: 'joined',
        isMember: true,
        isCreator: true,
        pendingRequestsCount: pendingCount
      });
    }

    // 2. Fetch communities where user is a joined/approved member (excluding communities they created)
    const memberships = await CommunityMember.find({
      userId: { $in: userIds },
      status: { $in: ['joined', 'approved'] }
    });
    const joinedCommunityIds = memberships.map(m => m.communityId.toString());

    const validObjectIds = joinedCommunityIds
      .filter(id => mongoose.Types.ObjectId.isValid(id))
      .map(id => new mongoose.Types.ObjectId(id));

    const joinedRaw = await Community.find({
      _id: { $in: [...validObjectIds, ...joinedCommunityIds] },
      creatorId: { $nin: userIds }
    }).sort({ createdAt: -1 });

    const joinedCommunities = joinedRaw.map(c => ({
      ...c.toObject(),
      joinStatus: 'joined',
      isMember: true,
      isCreator: false,
      pendingRequestsCount: 0
    }));

    return successResponse(res, 200, 'User communities fetched successfully', {
      createdCommunities,
      joinedCommunities,
      createdCount: createdCommunities.length,
      joinedCount: joinedCommunities.length,
      count: createdCommunities.length + joinedCommunities.length,
      communities: [...createdCommunities, ...joinedCommunities]
    });
  } catch (error) {
    next(error);
  }
};

// 2. Get Single Community by ID
const getCommunityById = async (req, res, next) => {
  try {
    const { communityId } = req.params;
    let community = null;

    if (mongoose.Types.ObjectId.isValid(communityId)) {
      community = await Community.findById(communityId);
    }
    if (!community) {
      community = await Community.findOne({ _id: communityId });
    }
    if (!community) {
      // Try finding by name regex
      community = await Community.findOne({ name: new RegExp(communityId, 'i') });
    }

    if (!community) {
      return errorResponse(res, 404, 'Community not found.');
    }

    // Determine current user join status
    const userId = req.user ? req.user._id : (req.query.userId || req.query.user_id || null);
    let joinStatus = 'none';

    if (userId) {
      const uStr = userId.toString();
      const membership = await CommunityMember.findOne({
        communityId: community._id.toString(),
        userId: uStr
      });
      if (membership) {
        joinStatus = membership.status; // 'pending' | 'approved' | 'joined'
      }
    }

    const isCreator = Boolean(userId && community.creatorId && community.creatorId.toString() === userId.toString());

    return successResponse(res, 200, 'Community details fetched successfully', {
      community: {
        ...community.toObject(),
        joinStatus,
        isMember: joinStatus === 'approved' || joinStatus === 'joined',
        isPending: joinStatus === 'pending',
        isCreator
      }
    });
  } catch (error) {
    next(error);
  }
};

// 3. Get All Posts for a Community
const getCommunityPosts = async (req, res, next) => {
  try {
    const { communityId } = req.params;
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 20;
    const userId = req.user ? req.user._id : (req.query.userId || req.query.user_id || null);

    let targetCommunityId = communityId;
    if (mongoose.Types.ObjectId.isValid(communityId)) {
      const comm = await Community.findById(communityId);
      if (comm) targetCommunityId = comm._id.toString();
    }

    const filter = {
      $or: [
        { communityId: targetCommunityId },
        { communityId: communityId }
      ]
    };

    const totalPosts = await Post.countDocuments(filter);
    const posts = await Post.find(filter)
      .slice('content', 2)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit);

    let checkUserId = userId ? userId.toString() : null;
    let checkUid = null;
    let checkObjId = null;
    if (checkUserId) {
      try {
        const u = await User.findOne({
          $or: [{ user_id: checkUserId }, { _id: mongoose.Types.ObjectId.isValid(checkUserId) ? checkUserId : null }]
        });
        if (u) {
          checkUid = u.user_id;
          checkObjId = u._id;
        }
      } catch (_) {}
      try {
        if (!checkObjId && mongoose.Types.ObjectId.isValid(checkUserId)) {
          checkObjId = new mongoose.Types.ObjectId(checkUserId);
        }
      } catch (_) {}
    }

    // Reuse formatPost structure
    const formatPost = (post) => {
      const cover = post.cover_image || post.cover_img || post.coverImage || '';
      let isSaved = false;
      let isSupported = false;
      if (checkUserId) {
        isSaved = Array.isArray(post.saved_by) && post.saved_by.some(u => {
          if (!u) return false;
          const s = u.toString();
          return s === checkUserId || (checkUid && s === checkUid) || (checkObjId && s === checkObjId.toString());
        });
        isSupported = Array.isArray(post.supported_by) && post.supported_by.some(u => {
          if (!u) return false;
          const s = u.toString();
          return s === checkUserId || (checkUid && s === checkUid) || (checkObjId && s === checkObjId.toString());
        });
      }

      return {
        post_id: post.post_id || post._id.toString(),
        _id: post._id.toString(),
        user_id: post.user_id?.toString() || '',
        username: (post.username && post.username !== 'Anonymous' && !post.username.match(/^[0-9a-fA-F]{24}$/))
          ? post.username
          : (post.author || post.name || 'Ryitu User'),
        profile_image: post.profile_image || '',
        title: post.title || '',
        caption: post.caption || '',
        categoryId: 'CAT00000004',
        category_id: 'CAT00000004',
        category: 'Ryitu',
        communityId: post.communityId || targetCommunityId,
        community_id: post.communityId || targetCommunityId,
        communityName: post.communityName || '',
        community_name: post.communityName || '',
        communityImage: post.communityImage || '',
        community_image: post.communityImage || '',
        isCommunityPost: true,
        content: post.content || [],
        cover_image: cover,
        cover_img: cover,
        coverImage: cover,
        support_count: post.support_count || 0,
        comment_count: post.comment_count !== undefined ? post.comment_count : (post.commentCount || 0),
        isSaved: Boolean(isSaved),
        isSupported: Boolean(isSupported),
        isLiked: Boolean(isSupported),
        views: post.views || 0,
        hashtags: post.hashtags || '',
        pageCount: post.pageCount || 0,
        pdf_url: post.pdf_url || post.pdf_path || '',
        pdfUrl: post.pdf_url || post.pdf_path || '',
        is_pdf: Boolean(post.is_pdf),
        created_at: post.createdAt || new Date(),
        createdAt: post.createdAt || new Date()
      };
    };

    return res.status(200).json({
      success: true,
      data: posts.map(formatPost),
      pagination: {
        page,
        limit,
        totalPages: Math.ceil(totalPosts / limit) || 1,
        totalPosts
      }
    });
  } catch (error) {
    next(error);
  }
};

// 4. Request to Join Community
const requestJoin = async (req, res, next) => {
  try {
    const { communityId } = req.params;
    const userId = req.user ? req.user._id : (req.body.userId || req.body.user_id || 'USR00000001');

    let community = null;
    if (mongoose.Types.ObjectId.isValid(communityId)) {
      community = await Community.findById(communityId);
    }
    if (!community) {
      community = await Community.findOne({ _id: communityId });
    }
    if (!community) {
      return errorResponse(res, 404, 'Community not found.');
    }

    // Check if membership request already exists
    let membership = await CommunityMember.findOne({
      communityId: community._id.toString(),
      userId: userId.toString()
    });

    if (membership && (membership.status === 'approved' || membership.status === 'joined')) {
      return successResponse(res, 200, 'Already a member of this community', {
        membership,
        status: membership.status,
        isPending: false,
        isMember: true
      });
    }

    const isNew = !membership;
    if (!membership) {
      membership = await CommunityMember.create({
        communityId: community._id.toString(),
        userId: userId.toString(),
        status: 'pending',
        requestedAt: new Date()
      });
    } else {
      membership.status = 'pending';
      membership.requestedAt = new Date();
      await membership.save();
    }

    // Dispatch join request notification to community owner (non-blocking)
    if (community.creatorId) {
      let actorName = req.user ? (req.user.name || req.user.username) : (req.body.username || req.body.name || '');
      let actorImage = req.user ? req.user.profileImage : (req.body.profileImage || '');

      if (!actorName) {
        try {
          const u = await User.findOne({
            $or: [
              ...(mongoose.Types.ObjectId.isValid(userId) ? [{ _id: userId }] : []),
              { user_id: userId },
              { username: userId }
            ]
          }).select('name username profileImage');
          if (u) {
            actorName = u.name || u.username || '';
            actorImage = u.profileImage || '';
          }
        } catch (_) {}
      }

      notificationService.createNotification({
        recipientId: community.creatorId,
        actorId: userId,
        actorName,
        actorImage,
        type: 'community_join_request',
        communityId: community._id.toString(),
        communityName: community.name
      }).catch(err => console.warn('[Join Request Notification Error]:', err.message));
    }

    return successResponse(res, isNew ? 201 : 200, 'Request to join submitted successfully', {
      membership,
      status: 'pending',
      isPending: true,
      isMember: false
    });
  } catch (error) {
    next(error);
  }

};

// 5. Check Membership Status
const getMembershipStatus = async (req, res, next) => {
  try {
    const { communityId } = req.params;
    const userId = req.user ? req.user._id : (req.query.userId || req.query.user_id || 'USR00000001');

    const membership = await CommunityMember.findOne({
      communityId: communityId.toString(),
      userId: userId.toString()
    });

    const status = membership ? membership.status : 'none';

    return successResponse(res, 200, 'Membership status fetched', {
      status,
      isPending: status === 'pending',
      isMember: status === 'approved' || status === 'joined'
    });
  } catch (error) {
    next(error);
  }
};

// 6. Get Available App Users to Add into Community
const getAvailableUsers = async (req, res, next) => {
  try {
    const { communityId } = req.params;
    const search = (req.query.q || req.query.search || '').trim();

    // Ensure sample users exist so testing/adding is immediately functional
    const userCount = await User.countDocuments();
    if (userCount < 3) {
      const dummyUsers = [
        { username: 'kavitha_farmer', name: 'Kavitha Farmer', email: 'kavitha@example.com', password: 'password123' },
        { username: 'selva_reader', name: 'Selvakumar Historian', email: 'selva@example.com', password: 'password123' },
        { username: 'priya_writer', name: 'Priya Reader', email: 'priya@example.com', password: 'password123' },
        { username: 'anbarasan_tech', name: 'Anbarasan Digital', email: 'anbu@example.com', password: 'password123' }
      ];
      for (const du of dummyUsers) {
        const exists = await User.findOne({ username: du.username });
        if (!exists) {
          await User.create(du);
        }
      }
    }

    const query = {};
    if (search) {
      const reg = new RegExp(search, 'i');
      query.$or = [{ name: reg }, { username: reg }, { email: reg }, { mobileNumber: reg }];
    }

    const users = await User.find(query).select('name username email mobileNumber profileImage').limit(40);

    // Get current community members
    const members = await CommunityMember.find({ communityId: communityId.toString() });
    const memberMap = new Map();
    for (const m of members) {
      memberMap.set(m.userId?.toString(), m.status);
    }

    let community = null;
    if (mongoose.Types.ObjectId.isValid(communityId)) {
      community = await Community.findById(communityId);
    }
    if (!community) {
      community = await Community.findOne({ _id: communityId });
    }
    const creatorId = community?.creatorId?.toString() || '';

    const formattedUsers = users.map(u => {
      const uid = u._id.toString();
      const status = memberMap.get(uid) || (uid === creatorId ? 'joined' : 'none');
      return {
        _id: uid,
        id: uid,
        user_id: uid,
        name: u.name || u.username || 'App Member',
        username: u.username || '',
        email: u.email || '',
        profileImage: u.profileImage || '',
        status,
        isMember: status === 'joined' || status === 'approved',
        isPending: status === 'pending'
      };
    });

    return successResponse(res, 200, 'Available users fetched successfully', {
      users: formattedUsers
    });
  } catch (error) {
    next(error);
  }
};

// 7. Add Users into Community (by Creator/Admin)
const addMembers = async (req, res, next) => {
  try {
    const { communityId } = req.params;
    let { userIds, userId } = req.body;

    if (!userIds && userId) {
      userIds = [userId];
    }
    if (!Array.isArray(userIds) || userIds.length === 0) {
      return errorResponse(res, 400, 'User IDs must be provided');
    }

    let community = null;
    if (mongoose.Types.ObjectId.isValid(communityId)) {
      community = await Community.findById(communityId);
    }
    if (!community) {
      community = await Community.findOne({ _id: communityId });
    }
    if (!community) {
      return errorResponse(res, 404, 'Community not found');
    }

    let newlyAddedCount = 0;
    const addedMembers = [];

    for (const uId of userIds) {
      const uStr = uId.toString();
      const existing = await CommunityMember.findOne({
        communityId: community._id.toString(),
        userId: uStr
      });

      if (!existing || (existing.status !== 'joined' && existing.status !== 'approved')) {
        newlyAddedCount++;
      }

      const updated = await CommunityMember.findOneAndUpdate(
        { communityId: community._id.toString(), userId: uStr },
        {
          communityId: community._id.toString(),
          userId: uStr,
          status: 'joined',
          approvedAt: new Date()
        },
        { upsert: true, new: true }
      );
      addedMembers.push(updated);
    }

    if (newlyAddedCount > 0) {
      community.memberCount = (community.memberCount || 0) + newlyAddedCount;
      await community.save();
    }

    // Notify added members asynchronously (non-blocking)
    const actorId = req.user ? req.user._id : (req.body.adminId || community.creatorId || 'USR00000001');
    const actorName = req.user ? (req.user.name || req.user.username) : '';
    const actorImage = req.user ? req.user.profileImage : '';

    for (const uId of userIds) {
      const uStr = uId.toString();
      if (uStr !== actorId.toString()) {
        notificationService.createNotification({
          recipientId: uStr,
          actorId,
          actorName,
          actorImage,
          type: 'community_member_added',
          communityId: community._id.toString(),
          communityName: community.name
        }).catch(err => console.warn('[Add member notification error]:', err.message));
      }
    }

    return successResponse(res, 200, 'Users added to community successfully', {
      addedCount: newlyAddedCount,
      memberCount: community.memberCount,
      addedMembers
    });
  } catch (error) {
    next(error);
  }
};

// 8. Get Pending Join Requests for a Community (Owner/Creator Only)
const getJoinRequests = async (req, res, next) => {
  try {
    const { communityId } = req.params;
    const currentUserId = req.user ? req.user._id : (req.query.userId || req.query.user_id);

    let community = null;
    if (mongoose.Types.ObjectId.isValid(communityId)) {
      community = await Community.findById(communityId);
    }
    if (!community) {
      community = await Community.findOne({ _id: communityId });
    }
    if (!community) {
      return errorResponse(res, 404, 'Community not found');
    }

    // Permission check: Verify current user is the community creator/owner
    const userIds = [currentUserId ? currentUserId.toString() : ''];
    if (req.user && req.user.user_id) userIds.push(req.user.user_id.toString());
    const isOwner = community.creatorId && userIds.includes(community.creatorId.toString());

    if (!isOwner && currentUserId) {
      return errorResponse(res, 403, 'Only the community creator can view pending join requests');
    }

    const pendingMembers = await CommunityMember.find({
      communityId: community._id.toString(),
      status: 'pending'
    }).sort({ requestedAt: -1, createdAt: -1 });

    const requests = [];
    for (const m of pendingMembers) {
      let uName = 'App User';
      let uUsername = '';
      let uImage = '';

      try {
        const u = await User.findOne({
          $or: [
            ...(mongoose.Types.ObjectId.isValid(m.userId) ? [{ _id: new mongoose.Types.ObjectId(m.userId) }] : []),
            { user_id: m.userId }
          ]
        }).select('name username profileImage');
        if (u) {
          uName = u.name || u.username || uName;
          uUsername = u.username || '';
          uImage = u.profileImage || '';
        }
      } catch (_) {}

      requests.push({
        id: m._id.toString(),
        _id: m._id.toString(),
        userId: m.userId.toString(),
        name: uName,
        username: uUsername,
        profileImage: uImage,
        status: m.status,
        requestedAt: m.requestedAt || m.createdAt,
        communityId: community._id.toString(),
        communityName: community.name
      });
    }

    return successResponse(res, 200, 'Pending join requests fetched successfully', {
      communityId: community._id.toString(),
      communityName: community.name,
      count: requests.length,
      requests
    });
  } catch (error) {
    next(error);
  }
};

// 9. Handle Join Request Action (Approve or Reject)
const handleJoinRequestAction = async (req, res, next) => {
  try {
    const { communityId, requestId } = req.params;
    const { action } = req.body; // 'approve' | 'reject'
    const currentUserId = req.user ? req.user._id : (req.body.userId || req.body.user_id);

    if (!['approve', 'reject'].includes(action)) {
      return errorResponse(res, 400, "Action must be 'approve' or 'reject'");
    }

    let community = null;
    if (mongoose.Types.ObjectId.isValid(communityId)) {
      community = await Community.findById(communityId);
    }
    if (!community) {
      community = await Community.findOne({ _id: communityId });
    }
    if (!community) {
      return errorResponse(res, 404, 'Community not found');
    }

    // Permission check
    const userIds = [currentUserId ? currentUserId.toString() : ''];
    if (req.user && req.user.user_id) userIds.push(req.user.user_id.toString());
    const isOwner = community.creatorId && userIds.includes(community.creatorId.toString());

    if (!isOwner && currentUserId) {
      return errorResponse(res, 403, 'Only the community creator can manage join requests');
    }

    let memberRequest = null;
    if (mongoose.Types.ObjectId.isValid(requestId)) {
      memberRequest = await CommunityMember.findById(requestId);
    }
    if (!memberRequest) {
      memberRequest = await CommunityMember.findOne({
        _id: requestId,
        communityId: community._id.toString()
      });
    }
    if (!memberRequest) {
      memberRequest = await CommunityMember.findOne({
        userId: requestId,
        communityId: community._id.toString(),
        status: 'pending'
      });
    }

    if (!memberRequest) {
      return errorResponse(res, 404, 'Join request not found');
    }

    if (action === 'approve') {
      const wasPending = memberRequest.status === 'pending';
      memberRequest.status = 'approved';
      memberRequest.approvedAt = new Date();
      await memberRequest.save();

      if (wasPending) {
        community.memberCount = (community.memberCount || 0) + 1;
        await community.save();
      }

      // Send approval notification to requester
      const actorName = req.user ? (req.user.name || req.user.username) : community.name;
      notificationService.createNotification({
        recipientId: memberRequest.userId,
        actorId: community.creatorId,
        actorName,
        type: 'community_join_approved',
        communityId: community._id.toString(),
        communityName: community.name
      }).catch(err => console.warn('[Approve notification error]:', err.message));

      const pendingCount = await CommunityMember.countDocuments({
        communityId: community._id.toString(),
        status: 'pending'
      });

      return successResponse(res, 200, 'Join request approved successfully', {
        request: memberRequest,
        status: 'approved',
        memberCount: community.memberCount,
        pendingCount
      });
    } else {
      // Reject
      memberRequest.status = 'rejected';
      await memberRequest.save();

      // Send rejection notification to requester
      const actorName = req.user ? (req.user.name || req.user.username) : community.name;
      notificationService.createNotification({
        recipientId: memberRequest.userId,
        actorId: community.creatorId,
        actorName,
        type: 'community_join_rejected',
        communityId: community._id.toString(),
        communityName: community.name
      }).catch(err => console.warn('[Reject notification error]:', err.message));

      const pendingCount = await CommunityMember.countDocuments({
        communityId: community._id.toString(),
        status: 'pending'
      });

      return successResponse(res, 200, 'Join request rejected', {
        request: memberRequest,
        status: 'rejected',
        pendingCount
      });
    }
  } catch (error) {
    next(error);
  }
};

module.exports = {
  seedSampleCommunitiesIfNeeded,
  getCommunities,
  createCommunity,
  getMyCommunities,
  getCommunityById,
  getCommunityPosts,
  requestJoin,
  getMembershipStatus,
  getAvailableUsers,
  addMembers,
  getJoinRequests,
  handleJoinRequestAction
};


