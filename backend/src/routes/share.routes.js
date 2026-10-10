const express = require('express');
const router = express.Router();
const Post = require('../models/Post');
const Community = require('../models/Community');

// Helper to escape HTML characters
const escapeHtml = (str) => {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
};

// 1. Share Post Redirect & Open Graph
router.get('/post/:id', async (req, res) => {
  const { id } = req.params;
  let title = 'Ryitu Story';
  let description = 'Read curated PDF books and stories on Ryitu.';
  let coverImage = '';

  try {
    let post = null;
    if (id.match(/^[0-9a-fA-F]{24}$/)) {
      post = await Post.findById(id);
    }
    if (!post) {
      post = await Post.findOne({ post_id: id });
    }
    if (post) {
      title = post.title || title;
      description = post.caption || post.title || description;
      coverImage = post.cover_image || '';
    }
  } catch (_) {}

  const host = req.get('host') || 'localhost:5000';
  const protocol = req.protocol || 'http';
  const fullCoverUrl = coverImage
    ? (coverImage.startsWith('http') ? coverImage : `${protocol}://${host}/uploads/covers/${coverImage}`)
    : `${protocol}://${host}/uploads/profile_images/default.png`;

  const deepLink = `ryitu://post/${encodeURIComponent(id)}`;

  // If client requested JSON
  if (req.headers.accept && req.headers.accept.includes('application/json')) {
    return res.status(200).json({
      success: true,
      title,
      description,
      deepLink,
      coverUrl: fullCoverUrl
    });
  }

  const html = `<!DOCTYPE html>
<html lang="ta">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)} - Ryitu</title>
  <meta name="description" content="${escapeHtml(description)}">
  
  <!-- Open Graph / WhatsApp / Facebook / Twitter -->
  <meta property="og:type" content="article">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:image" content="${escapeHtml(fullCoverUrl)}">
  <meta property="og:site_name" content="Ryitu">
  
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background: #f8f9fa;
      color: #1a1a1a;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 20px;
      box-sizing: border-box;
    }
    .card {
      background: white;
      border-radius: 24px;
      box-shadow: 0 10px 30px rgba(0,0,0,0.06);
      max-width: 420px;
      width: 100%;
      padding: 32px 24px;
      text-align: center;
    }
    .badge {
      display: inline-block;
      background: rgba(7, 41, 232, 0.08);
      color: #0729e8;
      padding: 6px 14px;
      border-radius: 20px;
      font-size: 13px;
      font-weight: 700;
      margin-bottom: 16px;
    }
    h1 {
      font-size: 22px;
      font-weight: 800;
      margin: 0 0 12px;
      color: #111827;
      line-height: 1.35;
    }
    p {
      color: #6b7280;
      font-size: 14px;
      line-height: 1.5;
      margin: 0 0 24px;
    }
    .btn {
      display: block;
      background: #0729e8;
      color: white;
      text-decoration: none;
      font-weight: 700;
      font-size: 16px;
      padding: 14px 20px;
      border-radius: 16px;
      box-shadow: 0 4px 14px rgba(7, 41, 232, 0.3);
      transition: transform 0.15s, background 0.15s;
    }
    .btn:hover {
      background: #041ca1;
      transform: translateY(-1px);
    }
    .hint {
      margin-top: 18px;
      font-size: 12px;
      color: #9ca3af;
    }
  </style>
  <script>
    // Automatic redirect to app via custom scheme
    window.onload = function() {
      setTimeout(function() {
        window.location.href = "${deepLink}";
      }, 300);
    };
  </script>
</head>
<body>
  <div class="card">
    <div class="badge">📖 Ryitu Story</div>
    <h1>${escapeHtml(title)}</h1>
    <p>${escapeHtml(description)}</p>
    <a href="${deepLink}" class="btn">Open in Ryitu App (ஆப்பில் திறக்க)</a>
    <div class="hint">Opening Ryitu app automatically...</div>
  </div>
</body>
</html>`;

  return res.status(200).send(html);
});

// 2. Share Community Redirect & Open Graph
router.get('/community/:id', async (req, res) => {
  const { id } = req.params;
  let name = 'Ryitu Community';
  let description = 'Connect with readers and discover curated stories on Ryitu.';
  let coverImage = '';

  try {
    let comm = null;
    if (id.match(/^[0-9a-fA-F]{24}$/)) {
      comm = await Community.findById(id);
    }
    if (!comm) {
      comm = await Community.findOne({ _id: id });
    }
    if (comm) {
      name = comm.name || name;
      description = comm.description || description;
      coverImage = comm.coverImage || comm.image || '';
    }
  } catch (_) {}

  const host = req.get('host') || 'localhost:5000';
  const protocol = req.protocol || 'http';
  const fullCoverUrl = coverImage
    ? (coverImage.startsWith('http') ? coverImage : `${protocol}://${host}/uploads/covers/${coverImage}`)
    : `${protocol}://${host}/uploads/profile_images/default.png`;

  const deepLink = `ryitu://community/${encodeURIComponent(id)}`;

  if (req.headers.accept && req.headers.accept.includes('application/json')) {
    return res.status(200).json({
      success: true,
      name,
      description,
      deepLink,
      coverUrl: fullCoverUrl
    });
  }

  const html = `<!DOCTYPE html>
<html lang="ta">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(name)} - Ryitu Community</title>
  <meta name="description" content="${escapeHtml(description)}">
  
  <!-- Open Graph -->
  <meta property="og:type" content="website">
  <meta property="og:title" content="${escapeHtml(name)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:image" content="${escapeHtml(fullCoverUrl)}">
  <meta property="og:site_name" content="Ryitu">
  
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background: #f8f9fa;
      color: #1a1a1a;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 20px;
      box-sizing: border-box;
    }
    .card {
      background: white;
      border-radius: 24px;
      box-shadow: 0 10px 30px rgba(0,0,0,0.06);
      max-width: 420px;
      width: 100%;
      padding: 32px 24px;
      text-align: center;
    }
    .badge {
      display: inline-block;
      background: rgba(7, 41, 232, 0.08);
      color: #0729e8;
      padding: 6px 14px;
      border-radius: 20px;
      font-size: 13px;
      font-weight: 700;
      margin-bottom: 16px;
    }
    h1 {
      font-size: 22px;
      font-weight: 800;
      margin: 0 0 12px;
      color: #111827;
      line-height: 1.35;
    }
    p {
      color: #6b7280;
      font-size: 14px;
      line-height: 1.5;
      margin: 0 0 24px;
    }
    .btn {
      display: block;
      background: #0729e8;
      color: white;
      text-decoration: none;
      font-weight: 700;
      font-size: 16px;
      padding: 14px 20px;
      border-radius: 16px;
      box-shadow: 0 4px 14px rgba(7, 41, 232, 0.3);
      transition: transform 0.15s, background 0.15s;
    }
    .btn:hover {
      background: #041ca1;
      transform: translateY(-1px);
    }
    .hint {
      margin-top: 18px;
      font-size: 12px;
      color: #9ca3af;
    }
  </style>
  <script>
    // Automatic redirect to app via custom scheme
    window.onload = function() {
      setTimeout(function() {
        window.location.href = "${deepLink}";
      }, 300);
    };
  </script>
</head>
<body>
  <div class="card">
    <div class="badge">🌟 Ryitu Community</div>
    <h1>${escapeHtml(name)}</h1>
    <p>${escapeHtml(description)}</p>
    <a href="${deepLink}" class="btn">Join Community (குழுவில் சேர)</a>
    <div class="hint">Opening Ryitu app automatically...</div>
  </div>
</body>
</html>`;

  return res.status(200).send(html);
});

module.exports = router;
