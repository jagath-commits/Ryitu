const Bookmark = require('../models/Bookmark');
const Book = require('../models/Book');
const { successResponse, errorResponse } = require('../utils/response.util');

const addBookmark = async (req, res, next) => {
  try {
    const { bookId } = req.params;
    const { pageNumber, note } = req.body;
    const effectiveUserId = req.user ? req.user._id : (req.body.userId || req.body.user_id || 'USR00000001');

    if (!pageNumber || pageNumber < 1) {
      return errorResponse(res, 400, 'Valid page number is required.');
    }

    const book = await Book.findOne({ _id: bookId, isDeleted: false });
    if (!book) {
      return errorResponse(res, 404, 'Book not found.');
    }

    // Upsert bookmark for this page
    const bookmark = await Bookmark.findOneAndUpdate(
      { userId: effectiveUserId, bookId, pageNumber },
      { note: (note || '').trim(), createdAt: new Date() },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    );

    return successResponse(res, 201, 'Bookmark saved successfully', { bookmark });
  } catch (error) {
    next(error);
  }
};

const getBookmarks = async (req, res, next) => {
  try {
    const { bookId } = req.params;
    const effectiveUserId = req.user ? req.user._id : (req.query.userId || req.query.user_id || 'USR00000001');

    const book = await Book.findOne({ _id: bookId, isDeleted: false });
    if (!book) {
      return errorResponse(res, 404, 'Book not found.');
    }

    const bookmarks = await Bookmark.find({
      userId: effectiveUserId,
      bookId
    }).sort({ pageNumber: 1 });

    return successResponse(res, 200, 'Bookmarks fetched successfully', {
      count: bookmarks.length,
      bookmarks
    });
  } catch (error) {
    next(error);
  }
};

const deleteBookmark = async (req, res, next) => {
  try {
    const { bookId, bookmarkId } = req.params;
    const effectiveUserId = req.user ? req.user._id : (req.body.userId || req.body.user_id || req.query.userId || null);

    const filter = { _id: bookmarkId, bookId };
    if (effectiveUserId) filter.userId = effectiveUserId;

    const bookmark = await Bookmark.findOneAndDelete(filter);

    if (!bookmark) {
      return errorResponse(res, 404, 'Bookmark not found.');
    }

    return successResponse(res, 200, 'Bookmark removed successfully', { bookmarkId });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  addBookmark,
  getBookmarks,
  deleteBookmark
};