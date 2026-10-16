const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');

const postSchema = new mongoose.Schema(
  {
    post_id: {
      type: String,
      default: () => uuidv4(),
      unique: true,
      index: true
    },
    user_id: {
      type: mongoose.Schema.Types.Mixed,
      required: true,
      index: true
    },
    username: {
      type: String,
      default: 'Anonymous'
    },
    profile_image: {
      type: String,
      default: ''
    },
    title: {
      type: String,
      required: [true, 'Please provide a title'],
      trim: true
    },
    caption: {
      type: String,
      default: ''
    },
    // Strictly Ryitu / Noolagam (Library / PDF) category
    categoryId: {
      type: String,
      default: 'CAT00000004'
    },
    category: {
      type: String,
      default: 'Ryitu'
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
    communityImage: {
      type: String,
      default: ''
    },
    content: {
      type: mongoose.Schema.Types.Mixed,
      default: []
    },
    cover_image: {
      type: String,
      default: ''
    },
    support_count: {
      type: Number,
      default: 0
    },
    supported_by: [
      {
        type: mongoose.Schema.Types.Mixed
      }
    ],
    saved_by: [
      {
        type: mongoose.Schema.Types.Mixed
      }
    ],
    views: {
      type: Number,
      default: 0
    },
    hashtags: {
      type: String,
      default: ''
    },
    pdf_path: {
      type: String,
      default: ''
    },
    pageCount: {
      type: Number,
      default: 0
    },
    pdf_url: {
      type: String,
      default: ''
    },
    is_pdf: {
      type: Boolean,
      default: false
    }
  },
  {
    timestamps: true
  }
);

// Index for search
postSchema.index({ title: 'text', caption: 'text', hashtags: 'text' });

module.exports = mongoose.model('Post', postSchema);
