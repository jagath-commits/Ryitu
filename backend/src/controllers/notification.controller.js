const mongoose = require('mongoose');
const Notification = require('../models/Notification');
const User = require('../models/User');
const { successResponse, errorResponse } = require('../utils/response.util');

/**
 * Resolves user IDs (both string user_id and ObjectId _id) for querying notifications
 */
const resolveUserIds = async (req) => {
  const ids = [];

  if (req.user) {
    if (req.user._id) ids.push(req.user._id.toString());
    if (req.user.user_id) ids.push(req.user.user_id.toString());
  }

  const queryId = req.query.userId || req.query.user_id || req.body.userId || req.body.user_id;
  if (queryId) {
    const qStr = queryId.toString();
    if (!ids.includes(qStr)) ids.push(qStr);

    try {
      const user = await User.findOne({
        $or: [
          ...(mongoose.Types.ObjectId.isValid(qStr) ? [{ _id: new mongoose.Types.ObjectId(qStr) }] : []),
          { user_id: qStr }
        ]
      }).select('_id user_id');
      if (user) {
        if (user._id && !ids.includes(user._id.toString())) ids.push(user._id.toString());
        if (user.user_id && !ids.includes(user.user_id.toString())) ids.push(user.user_id.toString());
      }
    } catch (_) {}
  }

  return ids;
};

// 1. Get Paginated Notifications (Newest First)
const getNotifications = async (req, res, next) => {
  try {
    const userIds = await resolveUserIds(req);

    if (userIds.length === 0) {
      return successResponse(res, 200, 'No user identifier provided', {
        notifications: [],
        unreadCount: 0,
        pagination: { page: 1, limit: 20, total: 0, totalPages: 0 }
      });
    }

    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 20;
    const unreadOnly = req.query.unreadOnly === 'true' || req.query.unread === 'true';

    const filter = {
      recipientId: { $in: userIds }
    };
    if (unreadOnly) {
      filter.isRead = false;
    }

    const total = await Notification.countDocuments(filter);
    const unreadCount = await Notification.countDocuments({
      recipientId: { $in: userIds },
      isRead: false
    });

    const notifications = await Notification.find(filter)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .lean();

    return successResponse(res, 200, 'Notifications retrieved successfully', {
      notifications: notifications.map((n) => ({
        id: n._id.toString(),
        _id: n._id.toString(),
        type: n.type,
        title: n.title,
        body: n.body,
        actorId: n.actorId,
        actorName: n.actorName,
        actorImage: n.actorImage,
        postId: n.postId,
        commentId: n.commentId,
        communityId: n.communityId,
        communityName: n.communityName,
        isRead: Boolean(n.isRead),
        createdAt: n.createdAt
      })),
      unreadCount,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit) || 1
      }
    });
  } catch (error) {
    next(error);
  }
};

// 2. Get Unread Notification Count
const getUnreadCount = async (req, res, next) => {
  try {
    const userIds = await resolveUserIds(req);

    if (userIds.length === 0) {
      return successResponse(res, 200, 'Unread count fetched', { unreadCount: 0 });
    }

    const unreadCount = await Notification.countDocuments({
      recipientId: { $in: userIds },
      isRead: false
    });

    return successResponse(res, 200, 'Unread count fetched', { unreadCount });
  } catch (error) {
    next(error);
  }
};

// 3. Mark Single Notification as Read
const markAsRead = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userIds = await resolveUserIds(req);

    const filter = { _id: id };
    if (userIds.length > 0) {
      filter.recipientId = { $in: userIds };
    }

    const updated = await Notification.findOneAndUpdate(
      filter,
      { isRead: true },
      { new: true }
    );

    if (!updated) {
      return errorResponse(res, 404, 'Notification not found or unauthorized');
    }

    return successResponse(res, 200, 'Notification marked as read', {
      notification: updated
    });
  } catch (error) {
    next(error);
  }
};

// 4. Mark All Notifications as Read
const markAllAsRead = async (req, res, next) => {
  try {
    const userIds = await resolveUserIds(req);

    if (userIds.length === 0) {
      return successResponse(res, 200, 'All notifications marked as read', { modifiedCount: 0 });
    }

    const result = await Notification.updateMany(
      { recipientId: { $in: userIds }, isRead: false },
      { isRead: true }
    );

    return successResponse(res, 200, 'All notifications marked as read', {
      modifiedCount: result.modifiedCount
    });
  } catch (error) {
    next(error);
  }
};

// 5. Delete Notification
const deleteNotification = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userIds = await resolveUserIds(req);

    const filter = { _id: id };
    if (userIds.length > 0) {
      filter.recipientId = { $in: userIds };
    }

    await Notification.findOneAndDelete(filter);
    return successResponse(res, 200, 'Notification removed successfully');
  } catch (error) {
    next(error);
  }
};

// 6. Test Push Notification & Status
const testPushNotification = async (req, res, next) => {
  try {
    const { isFirebaseConfigured, getMessaging } = require('../config/firebase');
    const userIds = await resolveUserIds(req);
    const targetUserId = userIds[0] || req.body.userId || req.body.user_id;

    let targetUser = null;
    if (targetUserId) {
      targetUser = await User.findOne({
        $or: [
          ...(typeof targetUserId === 'string' && targetUserId.match(/^[0-9a-fA-F]{24}$/)
            ? [{ _id: targetUserId }]
            : []),
          { user_id: targetUserId },
          { username: targetUserId }
        ]
      });
    }

    const configured = isFirebaseConfigured();
    const hasFcmToken = !!targetUser?.fcmToken;

    let pushSent = false;
    let pushError = null;

    if (configured && targetUser?.fcmToken) {
      try {
        const messaging = getMessaging();
        await messaging.send({
          token: targetUser.fcmToken,
          notification: {
            title: req.body.title || 'Ritpen Test Push',
            body: req.body.body || 'Push notifications are working properly!'
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'ritpen_notifications',
              sound: 'default'
            }
          }
        });
        pushSent = true;
      } catch (err) {
        pushError = err.message;
      }
    }

    return successResponse(res, 200, 'Push notification status', {
      firebaseConfigured: configured,
      hasFcmToken,
      fcmTokenPreview: targetUser?.fcmToken ? `${targetUser.fcmToken.substring(0, 15)}...` : null,
      pushSent,
      pushError
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
  deleteNotification,
  testPushNotification
};
