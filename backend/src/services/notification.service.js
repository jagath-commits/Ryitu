const mongoose = require('mongoose');
const Notification = require('../models/Notification');
const User = require('../models/User');
const { getMessaging } = require('../config/firebase');

/**
 * Truncate comment text safely for notification preview
 */
const formatCommentPreview = (text, maxLength = 50) => {
  if (!text) return '';
  const sanitized = text.replace(/[\r\n]+/g, ' ').trim();
  if (sanitized.length <= maxLength) return sanitized;
  return `${sanitized.substring(0, maxLength - 3)}...`;
};

/**
 * Standard notification title and body generator based on application specs
 */
const generateNotificationContent = (type, params = {}) => {
  const actorName = params.actorName || 'A user';
  const communityName = params.communityName || 'the community';
  const commentPreview = formatCommentPreview(params.commentText || '');

  switch (type) {
    case 'new_post':
      return {
        title: 'New Post',
        body: `${actorName} shared a new post.`
      };
    case 'post_like':
      return {
        title: 'New Like',
        body: `${actorName} liked your post.`
      };
    case 'post_comment':
      return {
        title: 'New Comment',
        body: commentPreview
          ? `${actorName} commented on your post: "${commentPreview}"`
          : `${actorName} commented on your post.`
      };
    case 'community_member_added':
      return {
        title: 'Added to Community',
        body: `${actorName} added you to "${communityName}".`
      };
    case 'community_join_request':
      return {
        title: 'New Community Join Request',
        body: `${actorName} requested to join "${communityName}".`
      };
    case 'community_join_approved':
      return {
        title: 'Join Request Approved',
        body: `Your request to join "${communityName}" has been approved.`
      };
    case 'community_join_rejected':
      return {
        title: 'Join Request Update',
        body: `Your request to join "${communityName}" was not approved.`
      };
    default:
      return {
        title: params.title || 'Notification',
        body: params.body || 'You have a new notification.'
      };
  }
};

/**
 * Non-blocking FCM push notification dispatcher.
 * Handles tokens safely without crashing operations if FCM delivery fails.
 */
const sendPushNotification = async (fcmToken, { title, body, data = {} }) => {
  if (!fcmToken || typeof fcmToken !== 'string' || !fcmToken.trim()) {
    return;
  }

  try {
    const messaging = getMessaging();
    if (messaging) {
      const sanitizedData = {};
      if (data && typeof data === 'object') {
        for (const [k, v] of Object.entries(data)) {
          if (v !== undefined && v !== null) {
            sanitizedData[String(k)] = String(v);
          }
        }
      }

      const response = await messaging.send({
        token: fcmToken.trim(),
        notification: {
          title: String(title || 'Ritpen'),
          body: String(body || '')
        },
        data: sanitizedData,
        android: {
          priority: 'high',
          notification: {
            channelId: 'ritpen_notifications',
            icon: 'ic_notification',
            color: '#0729E8',
            sound: 'default',
            priority: 'max',
            defaultSound: true,
            defaultVibrateTimings: true
          }
        }
      });
      console.log(`[FCM Push Success] Sent to ${fcmToken.substring(0, 10)}... (MessageId: ${response})`);
      return;
    }
  } catch (err) {
    console.warn('[FCM Push Delivery Note]:', err.code || err.message);
    // Auto-remove dead tokens so DB stays clean
    if (
      err.code === 'messaging/registration-token-not-registered' ||
      err.code === 'messaging/invalid-argument'
    ) {
      try {
        await User.updateMany({ fcmToken }, { $set: { fcmToken: '' } });
      } catch (_) {}
    }
  }
};

/**
 * Resolves user display name from DB if not provided or generic
 */
const resolveActorDetails = async (actorId, providedName, providedImage) => {
  let actorName = (providedName || '').trim();
  let actorImage = providedImage || '';

  if (
    !actorName ||
    actorName === 'Anonymous' ||
    actorName === 'Ryitu User' ||
    actorName.match(/^[0-9a-fA-F]{24}$/)
  ) {
    try {
      const user = await User.findOne({
        $or: [
          ...(actorId && actorId.toString().match(/^[0-9a-fA-F]{24}$/)
            ? [{ _id: actorId }]
            : []),
          { user_id: actorId },
          { username: actorId },
          { mobileNumber: actorId }
        ]
      }).select('name username profileImage');

      if (user) {
        actorName = user.name || user.username || actorName;
        actorImage = actorImage || user.profileImage || '';
      }
    } catch (_) {}
  }

  if (!actorName || actorName.match(/^[0-9a-fA-F]{24}$/)) {
    actorName = 'Ritpen User';
  }

  return { actorName, actorImage };
};

/**
 * Helper to match recipient against alternate user ID representations
 */
const findRecipientUser = async (recipientId) => {
  if (!recipientId) return null;
  try {
    return await User.findOne({
      $or: [
        ...(recipientId.toString().match(/^[0-9a-fA-F]{24}$/)
          ? [{ _id: recipientId }]
          : []),
        { user_id: recipientId.toString() },
        { username: recipientId.toString() }
      ]
    }).select('_id user_id name fcmToken');
  } catch (_) {
    return null;
  }
};

/**
 * Create a persistent notification record and dispatch push notification.
 * Safe, idempotent, with deduplication and self-notification prevention.
 */
const createNotification = async (params) => {
  try {
    const {
      recipientId,
      actorId,
      actorName: rawActorName,
      actorImage: rawActorImage,
      type,
      postId = null,
      commentId = null,
      communityId = null,
      communityName = '',
      commentText = '',
      overrideTitle = null,
      overrideBody = null
    } = params;

    if (!recipientId || !actorId || !type) {
      return null;
    }

    // Rule: Do not notify oneself
    if (recipientId.toString() === actorId.toString()) {
      return null;
    }

    // Resolve recipient user to check secondary IDs (e.g. user_id string vs _id ObjectId)
    const recipientUser = await findRecipientUser(recipientId);
    if (recipientUser) {
      const rId1 = recipientUser._id ? recipientUser._id.toString() : '';
      const rId2 = recipientUser.user_id ? recipientUser.user_id.toString() : '';
      const aId = actorId.toString();
      if (aId === rId1 || aId === rId2) {
        return null; // Self action
      }
    }

    // Resolve real display name of actor
    const { actorName, actorImage } = await resolveActorDetails(
      actorId,
      rawActorName,
      rawActorImage
    );

    // Generate consistent notification title & body
    const content = generateNotificationContent(type, {
      actorName,
      communityName,
      commentText
    });

    const finalTitle = overrideTitle || content.title;
    const finalBody = overrideBody || content.body;

    const fcmToken = recipientUser?.fcmToken;

    // Deduplication check for likes
    if (type === 'post_like' && postId) {
      const existing = await Notification.findOne({
        recipientId,
        actorId,
        type: 'post_like',
        postId
      });
      if (existing) {
        // Already notified about this like - refresh timestamp, mark unread, and return
        existing.createdAt = new Date();
        existing.isRead = false;
        await existing.save();
        if (fcmToken) {
          sendPushNotification(fcmToken, {
            title: finalTitle,
            body: finalBody,
            data: {
              notificationId: existing._id.toString(),
              type,
              postId: postId ? postId.toString() : '',
              actorName
            }
          });
        }
        return existing;
      }
    }

    // Join request notification handling
    if (type === 'community_join_request' && communityId) {
      const existing = await Notification.findOne({
        recipientId,
        actorId,
        type: 'community_join_request',
        communityId
      });
      if (existing) {
        // Refresh existing request notification and always deliver device push
        existing.createdAt = new Date();
        existing.isRead = false;
        await existing.save();
        if (fcmToken) {
          sendPushNotification(fcmToken, {
            title: finalTitle,
            body: finalBody,
            data: {
              notificationId: existing._id.toString(),
              type,
              communityId: communityId ? communityId.toString() : '',
              actorName
            }
          });
        }
        return existing;
      }
    }

    // Create in-app notification record in MongoDB
    const notification = await Notification.create({
      recipientId: recipientUser ? recipientUser._id.toString() : recipientId.toString(),
      actorId: actorId.toString(),
      actorName,
      actorImage,
      type,
      title: finalTitle,
      body: finalBody,
      postId: postId ? postId.toString() : null,
      commentId: commentId ? commentId.toString() : null,
      communityId: communityId ? communityId.toString() : null,
      communityName: communityName || '',
      isRead: false
    });

    // Deliver push notification if recipient has FCM token
    if (fcmToken) {
      sendPushNotification(fcmToken, {
        title: finalTitle,
        body: finalBody,
        data: {
          notificationId: notification._id.toString(),
          type,
          postId: postId ? postId.toString() : '',
          communityId: communityId ? communityId.toString() : '',
          actorName
        }
      });
    }

    return notification;
  } catch (error) {
    console.warn('[Notification Service Error]:', error.message);
    return null;
  }
};

/**
 * Batched Fan-out: Notify all registered users about a new post
 * Excludes author. Uses paginated chunking (100 users per batch) to ensure scalability.
 */
const fanOutNewPostNotification = async ({
  actorId,
  actorName: rawActorName,
  actorImage: rawActorImage,
  postId,
  postTitle
}) => {
  try {
    if (!postId || !actorId) return;

    const { actorName, actorImage } = await resolveActorDetails(
      actorId,
      rawActorName,
      rawActorImage
    );

    const content = generateNotificationContent('new_post', { actorName });
    const title = content.title;
    const body = content.body;

    const actorStr = actorId.toString();
    const isActorObjId = mongoose.Types.ObjectId.isValid(actorStr);

    const filter = {
      $and: [
        { _id: { $ne: isActorObjId ? new mongoose.Types.ObjectId(actorStr) : null } },
        { user_id: { $ne: actorStr } }
      ]
    };

    const batchSize = 100;
    let page = 0;
    let hasMore = true;

    while (hasMore) {
      const users = await User.find(filter)
        .select('_id user_id fcmToken')
        .skip(page * batchSize)
        .limit(batchSize)
        .lean();

      if (!users || users.length === 0) {
        break;
      }

      const notifications = [];
      for (const u of users) {
        const targetRecipientId = u._id ? u._id.toString() : u.user_id;
        notifications.push({
          recipientId: targetRecipientId,
          actorId: actorStr,
          actorName,
          actorImage,
          type: 'new_post',
          title,
          body,
          postId: postId.toString(),
          communityId: null,
          communityName: '',
          isRead: false,
          createdAt: new Date(),
          updatedAt: new Date()
        });

        // Dispatch push notification if FCM token present
        if (u.fcmToken) {
          sendPushNotification(u.fcmToken, {
            title,
            body,
            data: {
              type: 'new_post',
              postId: postId.toString(),
              actorName
            }
          });
        }
      }

      if (notifications.length > 0) {
        await Notification.insertMany(notifications, { ordered: false }).catch((e) => {
          console.warn('[Batch Post Notification insert error]:', e.message);
        });
      }

      if (users.length < batchSize) {
        hasMore = false;
      } else {
        page++;
      }
    }
  } catch (error) {
    console.warn('[Fan-out New Post Notification error]:', error.message);
  }
};

module.exports = {
  createNotification,
  fanOutNewPostNotification,
  formatCommentPreview,
  generateNotificationContent,
  sendPushNotification
};
