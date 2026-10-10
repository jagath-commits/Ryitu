const mongoose = require('mongoose');

const bookmarkSchema = new mongoose.Schema(
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
    pageNumber: {
      type: Number,
      required: [true, 'Page number is required'],
      min: [1, 'Page number must be at least 1']
    },
    note: {
      type: String,
      default: '',
      trim: true,
      maxlength: [500, 'Note cannot exceed 500 characters']
    },
    createdAt: {
      type: Date,
      default: Date.now
    }
  }
);

// Ensure uniqueness per user, book, and pageNumber
bookmarkSchema.index({ userId: 1, bookId: 1, pageNumber: 1 }, { unique: true });

module.exports = mongoose.model('Bookmark', bookmarkSchema);