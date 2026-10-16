const express = require('express');
const router = express.Router();
const bookController = require('../controllers/book.controller');
const bookmarkRoutes = require('./bookmark.routes');
const progressRoutes = require('./progress.routes');
const { optionalAuth } = require('../middleware/auth.middleware');
const { uploadPdf } = require('../middleware/upload.middleware');

router.use(optionalAuth);

// Nested resource routes
router.use('/:bookId/bookmarks', bookmarkRoutes);
router.use('/:bookId/progress', progressRoutes);

// Book CRUD routes
router.get('/', bookController.getBooks);
router.get('/:id', bookController.getBookById);
router.get('/:id/toc', bookController.getTableOfContents);
router.get('/:id/page/:pageNumber', bookController.getBookPageText);
router.post('/upload', uploadPdf, bookController.uploadBook);
router.put('/:id', bookController.updateBook);
router.delete('/:id', bookController.deleteBook);

module.exports = router;