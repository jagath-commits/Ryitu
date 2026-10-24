const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    recipientId: {
      type: mongoose.Schema.Types.Mixed,
      required: true,
      index: true
    },
    actorId: {
      type: mongoose.Schema.Types.Mixed,
      required: true
    },
    actorName: {
      type: String,
      required: true,
      trim: true
    },
    actorImage: {
      type: String,
      default: ''
    },
    type: {
      type: String,
      enum: [
        'new_post',
        'post_like',
        'post_comment',
        'community_member_added',
        'community_join_request',
        'community_join_approved',
        'community_join_rejected'
      ],
      required: true,
      index: true
    },
    title: {
      type: String,
      required: true,
      trim: true
    },
    body: {
      type: String,
      required: true,
      trim: true
    },
    postId: {
      type: String,
      default: null,
      index: true
    },
    commentId: {
      type: String,
      default: null
    },
    communityId: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
      index: true
    },
    communityName: {
      type: String,
      default: ''
    },
    isRead: {
      type: Boolean,
      default: false,
      index: true
    }
  },
  {
    timestamps: true
  }
);

// Indexes for fast queries
notificationSchema.index({ recipientId: 1, createdAt: -1 });
notificationSchema.index({ recipientId: 1, isRead: 1 });
notificationSchema.index({ recipientId: 1, type: 1, postId: 1 });
notificationSchema.index({ recipientId: 1, type: 1, communityId: 1 });

module.exports = mongoose.model('Notification', notificationSchema);
