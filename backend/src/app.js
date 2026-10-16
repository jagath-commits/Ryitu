const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');

const authRoutes = require('./routes/auth.routes');
const profileRoutes = require('./routes/profile.routes');
const postRoutes = require('./routes/post.routes');
const draftRoutes = require('./routes/draft.routes');
const bookRoutes = require('./routes/book.routes');
const communityRoutes = require('./routes/community.routes');
const shareRoutes = require('./routes/share.routes');
const { errorHandler } = require('./middleware/error.middleware');
const { successResponse } = require('./utils/response.util');

const app = express();

// Security Middlewares
app.use(helmet({
  crossOriginResourcePolicy: false // Allow mobile client to stream PDFs and images
}));
app.use(cors({ origin: '*' }));

// Logging
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

// Body parsing (support large payload for PDF pages JSON)
app.use(express.json({ limit: '100mb' }));
app.use(express.urlencoded({ extended: true, limit: '100mb' }));

// Serve uploaded files statically
const uploadsDir = path.join(__dirname, '../uploads');

// Valid 64x64 PNG fallback buffer
const DEFAULT_AVATAR_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAPElEQVR42u3PMQEAAAgEID+50b+VbXBBI2BNkgwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAuGv4AAf1/0g0AAAAASUVORK5CYII=',
  'base64'
);

// Fallback handlers for profile images and covers to prevent 404 HttpExceptions in mobile client
const handleProfileImageRequest = (req, res, next) => {
  const filename = req.params.filename;
  const profileDir = path.join(uploadsDir, 'profile_images');
  const targetPath = path.join(profileDir, filename);

  if (fs.existsSync(targetPath)) {
    return res.sendFile(targetPath);
  }

  if (fs.existsSync(profileDir)) {
    const files = fs.readdirSync(profileDir).filter(f => /\.(jpe?g|png|webp|svg)$/i.test(f));
    if (files.length > 0) {
      const sorted = files.map(f => {
        try {
          return { name: f, time: fs.statSync(path.join(profileDir, f)).mtimeMs };
        } catch (_) {
          return { name: f, time: 0 };
        }
      }).sort((a, b) => b.time - a.time);
      return res.sendFile(path.join(profileDir, sorted[0].name));
    }
  }

  res.set('Content-Type', 'image/png');
  return res.status(200).send(DEFAULT_AVATAR_PNG);
};

const handleCoverImageRequest = (req, res, next) => {
  const filename = req.params.filename;
  const coversDir = path.join(uploadsDir, 'covers');
  const targetPath = path.join(coversDir, filename);

  if (fs.existsSync(targetPath)) {
    // Explicitly set SVG content-type so Flutter's SvgPicture.network() works
    if (/\.svg$/i.test(filename)) {
      res.setHeader('Content-Type', 'image/svg+xml');
    }
    return res.sendFile(targetPath);
  }

  if (fs.existsSync(coversDir)) {
    const files = fs.readdirSync(coversDir).filter(f => /\.(jpe?g|png|webp|svg)$/i.test(f));
    if (files.length > 0) {
      const sorted = files.map(f => {
        try {
          return { name: f, time: fs.statSync(path.join(coversDir, f)).mtimeMs };
        } catch (_) {
          return { name: f, time: 0 };
        }
      }).sort((a, b) => b.time - a.time);
      return res.sendFile(path.join(coversDir, sorted[0].name));
    }
  }

  res.set('Content-Type', 'image/png');
  return res.status(200).send(DEFAULT_AVATAR_PNG);
};

// Mount image handlers before static fallbacks
app.get('/uploads/profile_images/:filename', handleProfileImageRequest);
app.get('/profile_images/:filename', handleProfileImageRequest);
app.get('/uploads/covers/:filename', handleCoverImageRequest);
app.get('/covers/:filename', handleCoverImageRequest);

app.use('/uploads', express.static(uploadsDir));
app.use('/uploads/profile_images', express.static(path.join(uploadsDir, 'profile_images')));
app.use('/uploads/page_images', express.static(path.join(uploadsDir, 'page_images')));
app.use('/uploads/covers', express.static(path.join(uploadsDir, 'covers'), {
  setHeaders: (res, filePath) => {
    if (/\.svg$/i.test(filePath)) res.setHeader('Content-Type', 'image/svg+xml');
  }
}));
app.use('/uploads/pdf', express.static(path.join(uploadsDir, 'pdf')));
app.use('/uploads/documents', express.static(path.join(uploadsDir, 'documents')));

// Direct path fallbacks for images and covers
app.use('/covers', express.static(path.join(uploadsDir, 'covers')));
app.use('/profile_images', express.static(path.join(uploadsDir, 'profile_images')));
app.use('/page_images', express.static(path.join(uploadsDir, 'page_images')));
app.use('/documents', express.static(path.join(uploadsDir, 'documents')));
app.use('/pdf', express.static(path.join(uploadsDir, 'pdf')));

// Health check endpoint
app.get('/api/health', (req, res) => {
  return successResponse(res, 200, 'Noolagam PDF Book Reader Backend API is healthy', {
    timestamp: new Date().toISOString(),
    status: 'up'
  });
});

// Trending hashtags fallback endpoint
app.get('/api/posts/hashtags/trending', (req, res) => {
  return res.status(200).json({ success: true, data: [] });
});

// Mount Routes
app.use('/api/auth', authRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/posts', postRoutes);
app.use('/api/draft', draftRoutes);
app.use('/api/books', bookRoutes);
app.use('/api/communities', communityRoutes);
app.use('/share', shareRoutes);
app.use('/api/share', shareRoutes);

// Catch 404 for undefined routes
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: `Cannot ${req.method} ${req.originalUrl}`,
    error: { code: 'NOT_FOUND' }
  });
});

// Centralized Error Handling
app.use(errorHandler);

module.exports = app;