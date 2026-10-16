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

/**
 * Detects if extracted text is predominantly Tamil Unicode text.
 * Threshold is 5% — any PDF with significant Tamil content is treated as Tamil.
 */
function isTamilText(text) {
  if (!text || text.trim().length === 0) return false;
  const tamilChars = (text.match(/[\u0B80-\u0BFF]/g) || []).length;
  if (tamilChars === 0) return false;
  const totalChars = text.replace(/\s/g, '').length;
  // If even 5% of non-space chars are Tamil Unicode → it is a Tamil PDF
  return totalChars > 0 && (tamilChars / totalChars) > 0.05;
}

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

    // Clean and normalize extracted Tamil text (Bamini, legacy fonts, kerning, Unicode)
    const cleanedText = cleanExtractedText(rawText);

    // Tamil PDF-ல் images return பண்ண வேண்டாம் — text மட்டும் return பண்ணு
    // KEY FIX: If ANY text was extracted from this page, never return images.
    // Images are only for completely unreadable pages (scanned/image-only PDFs).
    // This handles ALL Tamil encodings: Unicode, Bamini, TSCII — regardless of font.
    const hasTamilContent = isTamilText(rawText) || isTamilText(cleanedText);
    const hasExtractedText = (cleanedText.trim().length > 10) || (rawText.trim().length > 10);

    let images = [];
    if (!hasExtractedText) {
      // Zero text extracted → image-only PDF page → try pre-extracted page images
      try {
        const pageImagesDir = path.join(__dirname, '../../uploads/page_images');
        const bookIdStr = book._id.toString();
        const possibleNames = [
          `${bookIdStr}_page_${pageNum}.jpg`,
          `${bookIdStr}_page_${pageNum}.png`,
          `${bookIdStr}_p${pageNum}.jpg`,
          `${bookIdStr}_p${pageNum}.png`,
        ];
        for (const imgName of possibleNames) {
          if (fs.existsSync(path.join(pageImagesDir, imgName))) {
            images.push(`uploads/page_images/${imgName}`);
            break;
          }
        }
      } catch (_) {}
    }

    return successResponse(res, 200, 'Page text extracted successfully', {
      page: pageNum,
      text: cleanedText,
      images,
      isTamil: hasTamilContent
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

/**
 * Extract Table of Contents from PDF using pdf-parse outline/bookmarks
 */
const getTableOfContents = async (req, res, next) => {
  try {
    const { id } = req.params;
    const book = await Book.findOne({ _id: id, isDeleted: false });
    if (!book) {
      return errorResponse(res, 404, 'Book not found.');
    }

    const pdfFileName = path.basename(book.pdfUrl || '');
    const pdfPath = path.join(__dirname, '../../uploads/pdf', pdfFileName);

    if (!fs.existsSync(pdfPath)) {
      return errorResponse(res, 404, 'PDF file not found on disk.');
    }

    // Use pdf-lib to extract outline/bookmarks (Table of Contents)
    const pdfBytes = await fs.promises.readFile(pdfPath);
    const { PDFDocument: PDFDoc } = require('pdf-lib');
    const pdfDoc = await PDFDoc.load(pdfBytes, { ignoreEncryption: true });

    // Extract outline if available
    let toc = [];
    try {
      const context = pdfDoc.context;
      const catalogRef = context.trailerInfo.Root;
      const catalog = context.lookup(catalogRef);
      const outlinesRef = catalog.get(PDFDoc.name ? undefined : catalog.getAs ? undefined : undefined);

      // Try to read outline from PDF
      const rawCatalog = context.lookupMaybe(catalogRef);
      if (rawCatalog) {
        const outlineKey = Array.from(rawCatalog.entries ? rawCatalog.entries() : [])
          .find(([k]) => k.toString().includes('Outlines') || k.toString().includes('outline'));
        if (outlineKey) {
          // Outline exists but complex to parse — return empty TOC
        }
      }
    } catch (_) {}

    // If no TOC from outline, build a basic chapter list from page headings
    if (toc.length === 0) {
      try {
        const { PDFParse } = require('pdf-parse');
        const parser = new PDFParse({ data: pdfBytes });
        await parser.load();
        const totalPages = book.pageCount || pdfDoc.getPageCount();

        // Sample first few pages to find chapter headings
        const maxSample = Math.min(totalPages, 50);
        for (let p = 1; p <= maxSample; p++) {
          try {
            const pageResult = await parser.getPageText(p);
            let text = '';
            if (pageResult && typeof pageResult.text === 'string') {
              text = pageResult.text.trim();
            } else if (typeof pageResult === 'string') {
              text = pageResult.trim();
            }

            if (!text) continue;

            const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 0);
            for (const line of lines.slice(0, 5)) {
              // Detect chapter headings: short lines, possibly numbered, in Tamil or English
              const isTamilHeading = /^[\u0B80-\u0BFF\s\d\.]+$/.test(line) && line.length < 60;
              const isEnglishHeading = /^(chapter|அத்தியாயம்|பாடம்|பகுதி|\d+[\.\)]\s)/i.test(line);
              const isShortBoldLine = line.length < 50 && line.length > 2;

              if ((isTamilHeading || isEnglishHeading) && isShortBoldLine) {
                // Avoid duplicates
                if (!toc.find(t => t.title === line)) {
                  toc.push({ title: line, page: p });
                  break;
                }
              }
            }
          } catch (_) {}
        }

        await parser.destroy();
      } catch (_) {}
    }

    return successResponse(res, 200, 'Table of contents fetched', {
      toc,
      totalPages: book.pageCount || 0
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  uploadBook,
  getBooks,
  getBookById,
  updateBook,
  deleteBook,
  getBookPageText,
  getTableOfContents
};