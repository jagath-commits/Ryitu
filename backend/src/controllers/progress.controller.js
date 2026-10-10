const ReadingProgress = require('../models/ReadingProgress');
const Book = require('../models/Book');
const { successResponse, errorResponse } = require('../utils/response.util');

const getProgress = async (req, res, next) => {
  try {
    const { bookId } = req.params;
    const effectiveUserId = req.user ? req.user._id : (req.query.userId || req.query.user_id || 'USR00000001');

    const book = await Book.findOne({ _id: bookId, isDeleted: false });
    if (!book) {
      return errorResponse(res, 404, 'Book not found.');
    }

    let progress = await ReadingProgress.findOne({
      userId: effectiveUserId,
      bookId
    });

    if (!progress) {
      progress = await ReadingProgress.create({
        userId: effectiveUserId,
        bookId,
        currentPage: 1,
        totalPages: book.pageCount || 1,
        progressPercentage: 0,
        lastReadAt: new Date()
      });
    }

    return successResponse(res, 200, 'Reading progress fetched successfully', { progress });
  } catch (error) {
    next(error);
  }
};

const updateProgress = async (req, res, next) => {
  try {
    const { bookId } = req.params;
    const { currentPage, totalPages } = req.body;
    const effectiveUserId = req.user ? req.user._id : (req.body.userId || req.body.user_id || 'USR00000001');

    if (!currentPage || currentPage < 1) {
      return errorResponse(res, 400, 'Valid currentPage number is required.');
    }

    const book = await Book.findOne({ _id: bookId, isDeleted: false });
    if (!book) {
      return errorResponse(res, 404, 'Book not found.');
    }

    const actualTotalPages = totalPages || book.pageCount || 1;
    const safeCurrentPage = Math.min(currentPage, actualTotalPages);
    const progressPercentage = Math.min(100, Math.round((safeCurrentPage / actualTotalPages) * 100));

    const progress = await ReadingProgress.findOneAndUpdate(
      { userId: effectiveUserId, bookId },
      {
        currentPage: safeCurrentPage,
        totalPages: actualTotalPages,
        progressPercentage,
        lastReadAt: new Date()
      },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    );

    // Update book lastOpenedAt
    book.lastOpenedAt = new Date();
    await book.save();

    return successResponse(res, 200, 'Reading progress updated successfully', { progress });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getProgress,
  updateProgress
};