const mongoose = require('mongoose');

const communitySchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Community name is required'],
      trim: true,
      maxlength: [120, 'Community name cannot exceed 120 characters']
    },
    description: {
      type: String,
      default: '',
      trim: true,
      maxlength: [1000, 'Description cannot exceed 1000 characters']
    },
    image: {
      type: String,
      default: ''
    },
    coverImage: {
      type: String,
      default: ''
    },
    creatorId: {
      type: mongoose.Schema.Types.Mixed,
      default: 'USR00000001'
    },
    memberCount: {
      type: Number,
      default: 0
    }
  },
  {
    timestamps: true
  }
);

communitySchema.index({ name: 'text', description: 'text' });

module.exports = mongoose.model('Community', communitySchema);
