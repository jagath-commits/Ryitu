const mongoose = require('mongoose');

const readingProgressSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.Mixed,
      required: true,
      index: true
    },
    bookId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Book',
      required: true,
      index: true
    },
    currentPage: {
      type: Number,
      required: true,
      default: 1,
      min: [1, 'Page must be at least 1']
    },
    totalPages: {
      type: Number,
      required: true,
      default: 1,
      min: [1, 'Total pages must be at least 1']
    },
    progressPercentage: {
      type: Number,
      default: 0,
      min: 0,
      max: 100
    },
    lastReadAt: {
      type: Date,
      default: Date.now
    }
  },
  {
    timestamps: true
  }
);

// Unique progress per user and book
readingProgressSchema.index({ userId: 1, bookId: 1 }, { unique: true });

// Auto calculate progress percentage before saving
readingProgressSchema.pre('save', function (next) {
  if (this.totalPages > 0) {
    this.progressPercentage = Math.min(100, Math.round((this.currentPage / this.totalPages) * 100));
  }
  this.lastReadAt = new Date();
  next();
});

module.exports = mongoose.model('ReadingProgress', readingProgressSchema);