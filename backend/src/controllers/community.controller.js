const mongoose = require('mongoose');
const Community = require('../models/Community');
const CommunityMember = require('../models/CommunityMember');
const Post = require('../models/Post');
const { successResponse, errorResponse } = require('../utils/response.util');

const User = require('../models/User');

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
    const communities = await Community.find().sort({ memberCount: -1, createdAt: -1 });
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

    const defaultImage = (image && image.trim()) || 'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=600&q=80';
    const defaultCover = (coverImage && coverImage.trim()) || defaultImage;

    const community = await Community.create({
      name: name.trim(),
      description: description ? description.trim() : '',
      image: defaultImage,
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

// 1c. Get My Joined/Created Communities
const getMyCommunities = async (req, res, next) => {
  try {
    await seedSampleCommunitiesIfNeeded();
    const userId = req.user ? req.user._id : (req.query.userId || req.query.user_id || 'USR00000001');
    const uStr = userId ? userId.toString() : 'USR00000001';

    // Find memberships where user has joined or is approved
    const memberships = await CommunityMember.find({
      userId: uStr,
      status: { $in: ['joined', 'approved'] }
    });
    const joinedCommunityIds = memberships.map(m => m.communityId.toString());

    // Fetch communities where user is creator or a joined member
    const communities = await Community.find({
      $or: [
        { _id: { $in: joinedCommunityIds } },
        { creatorId: uStr }
      ]
    }).sort({ updatedAt: -1 });

    return successResponse(res, 200, 'User communities fetched successfully', {
      count: communities.length,
      communities: communities.map(c => ({
        ...c.toObject(),
        joinStatus: 'joined',
        isMember: true,
        isCreator: Boolean(c.creatorId && c.creatorId.toString() === uStr)
      }))
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
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit);

    // Reuse formatPost structure
    const formatPost = (post) => {
      const cover = post.cover_image || post.cover_img || post.coverImage || '';
      return {
        post_id: post.post_id || post._id.toString(),
        _id: post._id.toString(),
        user_id: post.user_id?.toString() || '',
        username: post.username || 'Anonymous',
        profile_image: post.profile_image || '',
        title: post.title || '',
        caption: post.caption || '',
        categoryId: 'CAT00000004',
        category: 'Ryitu',
        communityId: post.communityId || targetCommunityId,
        community_id: post.communityId || targetCommunityId,
        communityName: post.communityName || '',
        community_name: post.communityName || '',
        isCommunityPost: true,
        content: post.content || [],
        cover_image: cover,
        cover_img: cover,
        coverImage: cover,
        support_count: post.support_count || 0,
        views: post.views || 0,
        hashtags: post.hashtags || '',
        created_at: post.createdAt || new Date()
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

    if (membership) {
      return successResponse(res, 200, 'Membership request already exists', {
        membership,
        status: membership.status,
        isPending: membership.status === 'pending',
        isMember: membership.status === 'approved' || membership.status === 'joined'
      });
    }

    // Create new pending request
    membership = await CommunityMember.create({
      communityId: community._id.toString(),
      userId: userId.toString(),
      status: 'pending',
      requestedAt: new Date()
    });

    return successResponse(res, 201, 'Request to join submitted successfully', {
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

    return successResponse(res, 200, 'Users added to community successfully', {
      addedCount: newlyAddedCount,
      memberCount: community.memberCount,
      addedMembers
    });
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
  addMembers
};

