const mongoose = require('mongoose');

const communityMemberSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.Mixed,
      required: true,
      index: true
    },
    communityId: {
      type: mongoose.Schema.Types.Mixed,
      required: true,
      index: true
    },
    status: {
      type: String,
      enum: ['pending', 'approved', 'rejected', 'joined'],
      default: 'pending'
    },
    requestedAt: {
      type: Date,
      default: Date.now
    },
    approvedAt: {
      type: Date,
      default: null
    }
  },
  {
    timestamps: true
  }
);

// Unique compound index to prevent duplicate membership requests
communityMemberSchema.index({ userId: 1, communityId: 1 }, { unique: true });

module.exports = mongoose.model('CommunityMember', communityMemberSchema);
