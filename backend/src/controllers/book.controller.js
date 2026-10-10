const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const { PDFDocument } = require('pdf-lib');
const { PDFParse } = require('pdf-parse');
const { cleanExtractedText } = require('../utils/textCleaner.util');
const Book = require('../models/Book');
const ReadingProgress = require('../models/ReadingProgress');
const { storageService } = require('../services/storage.service');
const { createAndSaveDefaultCover } = require('../utils/coverGenerator');
const { successResponse, errorResponse } = require('../utils/response.util');

// Helper to sniff image extension from raw buffer
const getExtensionFromBuffer = (buffer) => {
  if (!buffer || buffer.length < 4) return 'png';
  if (buffer[0] === 0xFF && buffer[1] === 0xD8 && buffer[2] === 0xFF) return 'jpg';
  if (buffer[0] === 0x89 && buffer[1] === 0x50 && buffer[2] === 0x4E && buffer[3] === 0x47) return 'png';
  if (buffer[0] === 0x47 && buffer[1] === 0x49 && buffer[2] === 0x46) return 'gif';
  if (buffer[0] === 0x52 && buffer[1] === 0x49 && buffer[2] === 0x46 && buffer[3] === 0x46) return 'webp';
  return 'png';
};

// Helper to construct dynamic full URL matching client's host/ip
const getDynamicFileUrl = (req, fileName, subfolder = 'page_images') => {
  if (!fileName) return '';
  const safeSub = (subfolder || '').replace(/\\/g, '/');
  const safeName = path.basename(fileName);
  const subPath = safeSub ? `${safeSub}/${safeName}` : safeName;
  if (req) {
    const host = req.get('host');
    const protocol = req.protocol || 'http';
    if (host) {
      return `${protocol}://${host}/uploads/${subPath}`;
    }
  }
  return storageService.getFileUrl(fileName, subfolder);
};

const uploadBook = async (req, res, next) => {
  try {
    if (!req.file) {
      return errorResponse(res, 400, 'No PDF file uploaded. Please select a valid PDF.');
    }

    const originalFileName = req.file.originalname;
    const defaultTitle = path.parse(originalFileName).name.replace(/[-_]/g, ' ');
    const title = (req.body.title || defaultTitle).trim();
    const author = (req.body.author || 'Unknown Author').trim();
    const description = (req.body.description || '').trim();
    const fileSize = req.file.size;
    const pdfFileName = req.file.filename;

    // Calculate actual page count using pdf-lib
    let pageCount = 1;
    try {
      const pdfBytes = await fs.promises.readFile(req.file.path);
      const pdfDoc = await PDFDocument.load(pdfBytes, { ignoreEncryption: true });
      pageCount = pdfDoc.getPageCount() || 1;
    } catch (parseErr) {
      console.warn('[PDF Parse] Unable to count pages with pdf-lib, defaulting to 1:', parseErr.message);
    }

    // Generate beautiful custom cover
    const coverFileName = `cover_${uuidv4()}.svg`;
    const coversDir = path.join(__dirname, '../../uploads/covers');
    await fs.promises.mkdir(coversDir, { recursive: true });
    await createAndSaveDefaultCover(title, author, coversDir, coverFileName);

    const pdfUrl = storageService.getFileUrl(pdfFileName, 'pdf');
    const coverUrl = storageService.getFileUrl(coverFileName, 'covers');
    const effectiveUserId = req.user ? req.user._id : (req.body.userId || req.body.user_id || 'USR00000001');
    const communityId = req.body.communityId || req.body.community_id || null;

    // Create Book entry in MongoDB
    const book = await Book.create({
      userId: effectiveUserId,
      communityId,
      title,
      author,
      description,
      coverImage: coverUrl,
      pdfUrl,
      originalFileName,
      fileSize,
      pageCount,
      lastOpenedAt: new Date()
    });

    // Initialize ReadingProgress for the newly created book
    const progress = await ReadingProgress.create({
      userId: effectiveUserId,
      bookId: book._id,
      currentPage: 1,
      totalPages: pageCount,
      progressPercentage: 0,
      lastReadAt: new Date()
    });

    return successResponse(res, 201, 'Book uploaded and created successfully', {
      book,
      progress
    });
  } catch (error) {
    next(error);
  }
};

const getBooks = async (req, res, next) => {
  try {
    const { search, communityId } = req.query;
    const effectiveUserId = req.user ? req.user._id : (req.query.userId || req.query.user_id || null);
    const query = {
      isDeleted: false
    };

    if (communityId) {
      query.communityId = communityId;
    } else if (effectiveUserId) {
      query.userId = effectiveUserId;
    }

    if (search && search.trim()) {
      const searchRegex = new RegExp(search.trim(), 'i');
      query.$or = [{ title: searchRegex }, { author: searchRegex }];
    }

    const books = await Book.find(query).sort({ updatedAt: -1 }).lean();

    // Attach reading progress to each book
    const bookIds = books.map((b) => b._id);
    const progressFilter = { bookId: { $in: bookIds } };
    if (effectiveUserId) {
      progressFilter.userId = effectiveUserId;
    }
    const progressList = await ReadingProgress.find(progressFilter).lean();

    const progressMap = {};
    progressList.forEach((p) => {
      progressMap[p.bookId.toString()] = p;
    });

    const enrichedBooks = books.map((book) => {
      const p = progressMap[book._id.toString()] || {
        currentPage: 1,
        totalPages: book.pageCount || 1,
        progressPercentage: 0,
        lastReadAt: book.updatedAt
      };
      return {
        ...book,
        progress: p
      };
    });

    return successResponse(res, 200, 'Books fetched successfully', {
      count: enrichedBooks.length,
      books: enrichedBooks
    });
  } catch (error) {
    next(error);
  }
};

const getBookById = async (req, res, next) => {
  try {
    const book = await Book.findOne({
      _id: req.params.id,
      isDeleted: false
    }).lean();

    if (!book) {
      return errorResponse(res, 404, 'Book not found.');
    }

    const effectiveUserId = req.user ? req.user._id : (req.query.userId || req.query.user_id || 'USR00000001');
    let progress = await ReadingProgress.findOne({
      userId: effectiveUserId,
      bookId: book._id
    }).lean();

    if (!progress) {
      progress = {
        currentPage: 1,
        totalPages: book.pageCount || 1,
        progressPercentage: 0,
        lastReadAt: book.updatedAt
      };
    }

    return successResponse(res, 200, 'Book details fetched successfully', {
      book: {
        ...book,
        progress
      }
    });
  } catch (error) {
    next(error);
  }
};

const updateBook = async (req, res, next) => {
  try {
    const { title, author, description } = req.body;
    const effectiveUserId = req.user ? req.user._id : (req.body.userId || req.body.user_id || null);
    const query = { _id: req.params.id, isDeleted: false };
    if (effectiveUserId) query.userId = effectiveUserId;

    const book = await Book.findOne(query);

    if (!book) {
      return errorResponse(res, 404, 'Book not found.');
    }

    if (title) book.title = title.trim();
    if (author) book.author = author.trim();
    if (description !== undefined) book.description = description.trim();

    await book.save();

    return successResponse(res, 200, 'Book updated successfully', { book });
  } catch (error) {
    next(error);
  }
};

const deleteBook = async (req, res, next) => {
  try {
    const effectiveUserId = req.user ? req.user._id : (req.body.userId || req.body.user_id || null);
    const query = { _id: req.params.id, isDeleted: false };
    if (effectiveUserId) query.userId = effectiveUserId;

    const book = await Book.findOne(query);

    if (!book) {
      return errorResponse(res, 404, 'Book not found.');
    }

    // Soft delete
    book.isDeleted = true;
    await book.save();

    return successResponse(res, 200, 'Book deleted successfully', { bookId: book._id });
  } catch (error) {
    next(error);
  }
};

const getBookPageText = async (req, res, next) => {
  let parser = null;
  try {
    const { id, pageNumber } = req.params;
    const pageNum = parseInt(pageNumber, 10) || 1;
    const book = await Book.findOne({ _id: id, isDeleted: false });
    if (!book) {
      return errorResponse(res, 404, 'Book not found.');
    }

    const pdfFileName = path.basename(book.pdfUrl || '');
    const pdfPath = path.join(__dirname, '../../uploads/pdf', pdfFileName);

    if (!fs.existsSync(pdfPath)) {
      return errorResponse(res, 404, 'PDF file not found on disk.');
    }

    const fileBuffer = await fs.promises.readFile(pdfPath);
    parser = new PDFParse({ data: fileBuffer });
    await parser.load();
    const pageResult = await parser.getPageText(pageNum);

    let rawText = '';
    if (pageResult && typeof pageResult.text === 'string') {
      rawText = pageResult.text;
    } else if (pageResult && typeof pageResult === 'string') {
      rawText = pageResult;
    }

    const cleanedText = cleanExtractedText(rawText);

    // Extract images and diagrams for this page
    const pageImages = [];
    try {
      const imgRes = await parser.getImage({ partial: [pageNum], imageThreshold: 20, imageBuffer: true });
      if (imgRes && imgRes.pages && imgRes.pages[0] && Array.isArray(imgRes.pages[0].images)) {
        for (let idx = 0; idx < imgRes.pages[0].images.length; idx++) {
          const im = imgRes.pages[0].images[idx];
          if (im.data && im.data.length > 0) {
            const ext = getExtensionFromBuffer(im.data);
            const imgFileName = `book_${id}_p${pageNum}_img${idx + 1}.${ext}`;
            await storageService.saveFile(Buffer.from(im.data), imgFileName, 'page_images');
            const imgUrl = getDynamicFileUrl(req, imgFileName, 'page_images');
            pageImages.push(imgUrl);
          }
        }
      }
    } catch (imErr) {
      console.warn(`[Book Page ${pageNum}] Image extraction warning:`, imErr.message);
    }

    // If no raster images found, check if this page is a vector diagram/drawing
    if (pageImages.length === 0 && parser.doc) {
      try {
        const pageObj = await parser.doc.getPage(pageNum);
        const ops = await pageObj.getOperatorList();
        let vectorPathCount = 0;
        for (let k = 0; k < ops.fnArray.length; k++) {
          const fn = ops.fnArray[k];
          if (fn === 82 || fn === 84 || fn === 17 || fn === 18) {
            vectorPathCount++;
          }
        }
        if (vectorPathCount > 15 || (cleanedText.length < 50 && vectorPathCount > 5)) {
          const screenshot = await parser.getScreenshot({ partial: [pageNum], scale: 1.5 });
          if (screenshot && screenshot.pages && screenshot.pages[0] && screenshot.pages[0].data) {
            const diagFileName = `book_${id}_p${pageNum}_diag.png`;
            await storageService.saveFile(Buffer.from(screenshot.pages[0].data), diagFileName, 'page_images');
            const diagUrl = getDynamicFileUrl(req, diagFileName, 'page_images');
            pageImages.push(diagUrl);
          }
        }
      } catch (_) {}
    }

    return successResponse(res, 200, 'Page text extracted successfully', {
      page: pageNum,
      text: cleanedText,
      images: pageImages
    });
  } catch (error) {
    next(error);
  } finally {
    if (parser) {
      try {
        await parser.destroy();
      } catch (_) {}
      parser = null;
    }
  }
};

module.exports = {
  uploadBook,
  getBooks,
  getBookById,
  updateBook,
  deleteBook,
  getBookPageText
};