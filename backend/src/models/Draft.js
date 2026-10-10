const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');

const draftSchema = new mongoose.Schema(
  {
    draft_id: {
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
    title: {
      type: String,
      default: 'Untitled Draft'
    },
    caption: {
      type: String,
      default: ''
    },
    categoryId: {
      type: String,
      default: 'CAT00000004'
    },
    category: {
      type: String,
      default: 'Ryitu'
    },
    content: {
      type: mongoose.Schema.Types.Mixed,
      default: []
    },
    cover_image: {
      type: String,
      default: ''
    }
  },
  {
    timestamps: true
  }
);

module.exports = mongoose.model('Draft', draftSchema);
