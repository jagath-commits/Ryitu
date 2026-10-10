const mongoose = require('mongoose');

const bookSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.Mixed,
      required: [true, 'Book must belong to a user'],
      index: true
    },
    communityId: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
      index: true
    },
    title: {
      type: String,
      required: [true, 'Please provide a book title'],
      trim: true,
      maxlength: [200, 'Title cannot exceed 200 characters']
    },
    author: {
      type: String,
      default: 'Unknown Author',
      trim: true,
      maxlength: [100, 'Author name cannot exceed 100 characters']
    },
    description: {
      type: String,
      default: '',
      trim: true,
      maxlength: [2000, 'Description cannot exceed 2000 characters']
    },
    coverImage: {
      type: String,
      default: ''
    },
    pdfUrl: {
      type: String,
      required: [true, 'PDF file URL is required']
    },
    originalFileName: {
      type: String,
      required: [true, 'Original file name is required']
    },
    fileSize: {
      type: Number,
      required: [true, 'File size is required']
    },
    pageCount: {
      type: Number,
      default: 0
    },
    lastOpenedAt: {
      type: Date,
      default: null
    },
    isDeleted: {
      type: Boolean,
      default: false,
      index: true
    }
  },
  {
    timestamps: true
  }
);

// Compound index for user books listing
bookSchema.index({ userId: 1, isDeleted: 1, updatedAt: -1 });

// Text search on title and author
bookSchema.index({ title: 'text', author: 'text' });

module.exports = mongoose.model('Book', bookSchema);