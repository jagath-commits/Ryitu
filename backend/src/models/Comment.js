const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema(
  {
    post_id: {
      type: String,
      required: true,
      index: true
    },
    user_id: {
      type: mongoose.Schema.Types.Mixed,
      required: true,
      index: true
    },
    username: {
      type: String,
      default: 'Ryitu User'
    },
    profile_image: {
      type: String,
      default: ''
    },
    text: {
      type: String,
      required: [true, 'Comment text is required'],
      trim: true
    },
    likes_count: {
      type: Number,
      default: 0
    },
    liked_by: [
      {
        type: mongoose.Schema.Types.Mixed
      }
    ],
    parent_comment_id: {
      type: String,
      default: null,
      index: true
    }
  },
  {
    timestamps: true
  }
);

module.exports = mongoose.model('Comment', commentSchema);
