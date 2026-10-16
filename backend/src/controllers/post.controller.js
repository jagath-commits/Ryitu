const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const { PDFParse } = require('pdf-parse');
const { cleanExtractedText } = require('../utils/textCleaner.util');
const Post = require('../models/Post');
const Comment = require('../models/Comment');
const Draft = require('../models/Draft');
const User = require('../models/User');
const { storageService } = require('../services/storage.service');
const { successResponse, errorResponse } = require('../utils/response.util');

// In-memory cache for document extraction
const extractionCache = new Map();

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

// Helper to format post for mobile client
const formatPost = (post) => {
  const cover = post.cover_image || post.cover_img || post.coverImage || '';
  return {
    post_id: post.post_id || post._id.toString(),
    _id: post._id.toString(),
    user_id: post.user_id?.toString() || '',
    username: (post.username && post.username !== 'Anonymous' && !post.username.match(/^[0-9a-fA-F]{24}$/))
      ? post.username
      : (post.author || post.name || 'Ryitu User'),
    profile_image: post.profile_image || '',
    title: post.title || '',
    caption: post.caption || '',
    categoryId: 'CAT00000004',
    category_id: 'CAT00000004',
    category: 'Ryitu',
    communityId: post.communityId || null,
    community_id: post.communityId || null,
    communityName: post.communityName || '',
    community_name: post.communityName || '',
    communityImage: post.communityImage || '',
    community_image: post.communityImage || '',
    isCommunityPost: Boolean(post.communityId),
    content: post.content || [],
    cover_image: cover,
    cover_img: cover,
    coverImage: cover,
    support_count: post.support_count || 0,
    comment_count: post.comment_count !== undefined ? post.comment_count : (post.commentCount || 0),
    isSaved: Boolean(post.isSaved),
    isSupported: Boolean(post.isSupported),
    isLiked: Boolean(post.isLiked !== undefined ? post.isLiked : post.isSupported),
    views: post.views || 0,
    hashtags: post.hashtags || '',
    // Page count for feed badge — how many pages this story/PDF has
    pageCount: post.pageCount || 0,
    page_count: post.pageCount || 0,
    totalPages: post.pageCount || 0,
    // PDF fields
    pdf_url: post.pdf_url || post.pdf_path || '',
    pdfUrl: post.pdf_url || post.pdf_path || '',
    is_pdf: Boolean(post.is_pdf),
    created_at: post.createdAt || new Date(),
    createdAt: post.createdAt || new Date()
  };
};

// 1. Extract Document (PDF with Images, Diagrams, and Clean Tamil/English Text)
const extractDocument = async (req, res, next) => {
  let parser = null;
  let filePath = null;
  try {
    if (!req.file) {
      return errorResponse(res, 400, 'No document uploaded');
    }

    filePath = req.file.path;
    const fileBuffer = await fs.promises.readFile(filePath);

    let extractedText = '';
    let totalPages = 0;
    const extractedPages = [];
    let totalImages = 0;

    const isPdf = !req.file.originalname || req.file.originalname.toLowerCase().endsWith('.pdf') || (req.file.mimetype && req.file.mimetype.includes('pdf'));

    if (isPdf) {
      try {
        parser = new PDFParse({ data: fileBuffer });
        await parser.load();
        totalPages = parser.doc ? parser.doc.numPages : 0;

        // 1. Extract text page-by-page
        const textResult = await parser.getText({
          pageJoiner: ''
        });

        const pagesArray = (textResult && Array.isArray(textResult.pages)) ? textResult.pages : [];
        if (textResult && textResult.total) {
          totalPages = Math.max(totalPages, textResult.total);
        } else if (pagesArray.length > 0) {
          totalPages = Math.max(totalPages, pagesArray.length);
        }
        if (totalPages === 0) totalPages = 1;
        totalPages = Math.min(totalPages, 5000);

        // 2. Extract embedded images and diagrams intelligently
        const imagesByPage = new Map();

        const processImagePages = async (pages) => {
          if (!Array.isArray(pages)) return;
          for (const p of pages) {
            const pNum = p.pageNumber;
            const pageImgs = [];
            if (Array.isArray(p.images)) {
              for (let idx = 0; idx < p.images.length; idx++) {
                const im = p.images[idx];
                if (im.data && im.data.length > 0) {
                  const ext = getExtensionFromBuffer(im.data);
                  const imgFileName = `doc_img_${uuidv4()}.${ext}`;
                  await storageService.saveFile(Buffer.from(im.data), imgFileName, 'page_images');
                  const imgUrl = getDynamicFileUrl(req, imgFileName, 'page_images');
                  pageImgs.push({
                    url: imgUrl,
                    width: im.width || 400,
                    height: im.height || 400,
                    name: im.name || `image_${pNum}_${idx + 1}`
                  });
                  totalImages++;
                }
              }
            }
            if (pageImgs.length > 0) {
              const existing = imagesByPage.get(pNum) || [];
              imagesByPage.set(pNum, existing.concat(pageImgs));
            }
          }
        };

        if (totalPages <= 30) {
          // Documents <= 30 pages (e.g. standard English articles, short documents): extract all pages directly
          try {
            const imgResult = await parser.getImage({ imageThreshold: 20, imageBuffer: true });
            if (imgResult && Array.isArray(imgResult.pages)) {
              await processImagePages(imgResult.pages);
            }
          } catch (imgErr) {
            console.warn('[PDF Extract] Image extraction warning:', imgErr.message);
          }
        } else {
          // Large documents (e.g. books up to 5000 pages):
          // Identify candidate pages: first 25 pages (covers, frontispiece, plates),
          // sparse text pages (< 120 chars: artwork, diagrams, photos), and last 5 pages
          const candidateSet = new Set();
          const firstPagesCount = Math.min(25, totalPages);
          for (let p = 1; p <= firstPagesCount; p++) {
            candidateSet.add(p);
          }
          for (let p = 1; p <= totalPages; p++) {
            const pageText = (pagesArray.length >= p && pagesArray[p - 1]) ? (pagesArray[p - 1].text || '').trim() : '';
            if (pageText.length < 120) {
              candidateSet.add(p);
            }
          }
          const lastPagesCount = Math.min(5, totalPages);
          for (let p = Math.max(1, totalPages - lastPagesCount + 1); p <= totalPages; p++) {
            candidateSet.add(p);
          }

          // Sort and cap candidate pages to top 80 to guarantee fast processing without timeout
          const candidatePages = Array.from(candidateSet).sort((a, b) => a - b).slice(0, 80);

          // Process in batches of 15 pages
          const batchSize = 15;
          for (let i = 0; i < candidatePages.length; i += batchSize) {
            const batch = candidatePages.slice(i, i + batchSize);
            try {
              const imgResult = await parser.getImage({ partial: batch, imageThreshold: 20, imageBuffer: true });
              if (imgResult && Array.isArray(imgResult.pages)) {
                await processImagePages(imgResult.pages);
              }
            } catch (batchErr) {
              console.warn('[PDF Extract] Image batch warning:', batchErr.message);
            }
          }
        }

        // 3. Page-by-page text cleaning and vector diagram detection
        for (let pNum = 1; pNum <= totalPages; pNum++) {
          let pText = '';
          if (pagesArray.length >= pNum && pagesArray[pNum - 1]) {
            pText = cleanExtractedText(pagesArray[pNum - 1].text || '');
          }

          let pImages = imagesByPage.get(pNum) || [];

          // If page has no raster images, check if it contains covers, illustrations, or vector diagrams
          const isCoverOrPlate = (pNum <= 15 || pNum > totalPages - 5) && pImages.length === 0;
          const isSparseText = (pText.length < 120);
          const shouldCheckVisual = parser.doc && (totalPages <= 50 || isCoverOrPlate || isSparseText);
          if (pImages.length === 0 && shouldCheckVisual) {
            try {
              const pageObj = await parser.doc.getPage(pNum);
              const ops = await pageObj.getOperatorList();
              const hasOps = ops && ops.fnArray && ops.fnArray.length > 0;
              let hasImageOp = false;
              let vectorPathCount = 0;
              if (hasOps) {
                for (let k = 0; k < ops.fnArray.length; k++) {
                  const fn = ops.fnArray[k];
                  // 84=paintFormXObject, 85=paintImageXObject, 86=paintInlineImageXObject, 87=paintImageXObjectGroup
                  if (fn === 84 || fn === 85 || fn === 86 || fn === 87) {
                    hasImageOp = true;
                    vectorPathCount++;
                  } else if (fn === 82 || fn === 17 || fn === 18 || fn === 19 || fn === 20) {
                    // constructPath, fill, eoFill, stroke
                    vectorPathCount++;
                  }
                }
              }

              // Visual page condition:
              // 1. Cover or plate: very sparse text (<50 chars) and has any drawing/image operators
              // 2. Unextracted image operator: hasImageOp (84/85/86/87)
              // 3. Significant vector diagram / drawing / chart: vectorPathCount >= 8
              const isVisualPage = hasOps && (
                (pText.length < 50) ||
                hasImageOp ||
                (vectorPathCount >= 8)
              );

              if (isVisualPage) {
                const screenshot = await parser.getScreenshot({ partial: [pNum], scale: 1.5 });
                if (screenshot && screenshot.pages && screenshot.pages[0] && screenshot.pages[0].data) {
                  const diagFileName = `doc_diag_${uuidv4()}.png`;
                  await storageService.saveFile(Buffer.from(screenshot.pages[0].data), diagFileName, 'page_images');
                  const diagUrl = getDynamicFileUrl(req, diagFileName, 'page_images');
                  pImages.push({
                    url: diagUrl,
                    width: screenshot.pages[0].width || 800,
                    height: screenshot.pages[0].height || 1000,
                    name: `diagram_p${pNum}`,
                    isDiagram: true
                  });
                  totalImages++;
                }
              }
            } catch (_) {}
          }

          extractedPages.push({
            pageNumber: pNum,
            text: pText,
            images: pImages
          });
        }

        // Combine text for backward compatibility
        extractedText = extractedPages.map(p => p.text).filter(t => t.length > 0).join('\n\n');
        if (!extractedText && textResult && typeof textResult.text === 'string') {
          extractedText = cleanExtractedText(textResult.text);
        }
      } catch (err) {
        console.warn('[PDF Extract] PDF parsing exception:', err.message);
      } finally {
        if (parser) {
          try {
            await parser.destroy();
          } catch (_) {}
          parser = null;
        }
      }
    }

    // If PDFParse returned no text, check if plain text file (.txt)
    if (!extractedText || extractedText.trim().length === 0) {
      const isPlainText = req.file.originalname && req.file.originalname.toLowerCase().endsWith('.txt');
      if (isPlainText) {
        extractedText = cleanExtractedText(fileBuffer.toString('utf8'));
        if (extractedPages.length === 0) {
          extractedPages.push({
            pageNumber: 1,
            text: extractedText,
            images: []
          });
          totalPages = 1;
        }
      }
    }

    // Safety checks for binary garbage (e.g. corrupted PDF)
    if (extractedText) {
      const controlChars = (extractedText.match(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g) || []).length;
      if (controlChars > 50 && controlChars / extractedText.length > 0.05) {
        extractedText = '';
      }
    }

    if (!extractedText || extractedText.trim().length === 0) {
      extractedText = (totalImages > 0) ? '' : 'Extracted Document Content';
    }

    // Allow large document text without truncation
    if (extractedText.length > 60000000) {
      extractedText = extractedText.substring(0, 60000000);
    }

    const extractionId = uuidv4();
    const CHUNK_SIZE = 30000;
    const chunks = [];
    for (let i = 0; i < extractedText.length; i += CHUNK_SIZE) {
      chunks.push(extractedText.substring(i, i + CHUNK_SIZE));
    }
    if (chunks.length === 0) {
      chunks.push(extractedText || '');
    }

    extractionCache.set(extractionId, {
      text: extractedText,
      chunks,
      totalPages,
      totalImages,
      pages: extractedPages,
      createdAt: Date.now()
    });

    // Cleanup old extractions (older than 2 hours)
    const twoHoursAgo = Date.now() - 2 * 60 * 60 * 1000;
    for (const [key, val] of extractionCache.entries()) {
      if (val.createdAt < twoHoursAgo) {
        extractionCache.delete(key);
      }
    }

    return res.status(200).json({
      success: true,
      extractionId,
      totalPages,
      totalImages,
      totalChunks: chunks.length,
      pages: extractedPages
    });
  } catch (error) {
    if (parser) {
      try {
        await parser.destroy();
      } catch (_) {}
    }
    next(error);
  } finally {
    if (filePath) {
      try {
        await fs.promises.unlink(filePath);
      } catch (_) {}
    }
  }
};

// 2. Get Full Extracted Document
const getDocumentFull = async (req, res) => {
  const { extractionId } = req.params;
  const extraction = extractionCache.get(extractionId);
  if (!extraction) {
    return res.status(404).json({ success: false, message: 'Extraction session not found or expired' });
  }
  return res.status(200).json({
    success: true,
    text: extraction.text,
    totalPages: extraction.totalPages,
    totalImages: extraction.totalImages || 0,
    pages: extraction.pages || []
  });
};

// 3. Get Document Chunk
const getDocumentChunk = async (req, res) => {
  const { extractionId, chunkIndex } = req.params;
  const extraction = extractionCache.get(extractionId);
  if (!extraction) {
    return res.status(404).json({ success: false, message: 'Extraction session not found or expired' });
  }
  const idx = parseInt(chunkIndex, 10);
  const chunk = extraction.chunks[idx] || '';
  return res.status(200).json({
    success: true,
    chunk
  });
};

// 4. Get Posts (List with pagination & search - only Noolagam)
const getPosts = async (req, res, next) => {
  try {
    try {
      const { seedSampleCommunitiesIfNeeded } = require('./community.controller');
      await seedSampleCommunitiesIfNeeded();
    } catch (_) {}

    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 10;
    const search = req.query.search || '';

    const filter = {
      // Strictly Ryitu / Noolagam category
      $or: [
        { categoryId: { $in: ['CAT00000004', '4'] } },
        { category: { $in: ['Ryitu', 'நூலகம்'] } },
        { categoryId: { $exists: false } }
      ]
    };

    if (search.trim()) {
      filter.$and = [
        {
          $or: [
            { title: { $regex: search.trim(), $options: 'i' } },
            { caption: { $regex: search.trim(), $options: 'i' } },
            { hashtags: { $regex: search.trim(), $options: 'i' } }
          ]
        }
      ];
    }

    const totalPosts = await Post.countDocuments(filter);
    const totalPages = Math.ceil(totalPosts / limit) || 1;

    const posts = await Post.find(filter)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit);

    // Resolve missing or 'Anonymous' usernames from User collection
    const userIdsToLookup = [];
    posts.forEach(p => {
      const u = p.username;
      if (!u || u === 'Anonymous' || u.match(/^[0-9a-fA-F]{24}$/)) {
        if (p.user_id) userIdsToLookup.push(p.user_id);
      }
    });

    if (userIdsToLookup.length > 0) {
      try {
        const userDocs = await User.find({
          $or: [
            { _id: { $in: userIdsToLookup.filter(id => (typeof id === 'string' && id.match(/^[0-9a-fA-F]{24}$/)) || (id && id._bsontype === 'ObjectID')) } },
            { user_id: { $in: userIdsToLookup } }
          ]
        }).select('_id user_id username name profileImage');

        const userMap = new Map();
        userDocs.forEach(ud => {
          const name = ud.username || ud.name;
          if (name) {
            if (ud._id) userMap.set(ud._id.toString(), { name, profileImage: ud.profileImage });
            if (ud.user_id) userMap.set(ud.user_id.toString(), { name, profileImage: ud.profileImage });
          }
        });

        posts.forEach(p => {
          const u = p.username;
          if (!u || u === 'Anonymous' || u.match(/^[0-9a-fA-F]{24}$/)) {
            const match = userMap.get(p.user_id ? p.user_id.toString() : '');
            if (match) {
              p.username = match.name;
              if (!p.profile_image && match.profileImage) {
                p.profile_image = match.profileImage;
              }
            }
          }
        });
      } catch (_) {}
    }

    // Lookup comment counts in batch
    const postIds = posts.map(p => p.post_id || p._id.toString());
    const countMap = new Map();
    try {
      const commentCounts = await Comment.aggregate([
        { $match: { post_id: { $in: postIds } } },
        { $group: { _id: '$post_id', count: { $sum: 1 } } }
      ]);
      commentCounts.forEach(c => countMap.set(c._id, c.count));
    } catch (_) {}

    // Check interaction status if user is provided
    const checkUserId = (req.user ? req.user._id.toString() : (req.query.userId || req.query.user_id || ''))?.toString() || '';
    let checkObjId = null;
    let checkUid = checkUserId;
    if (checkUserId && checkUserId.match(/^[0-9a-fA-F]{24}$/)) {
      try { checkObjId = new (require('mongoose').Types.ObjectId)(checkUserId); } catch (_) {}
    }

    posts.forEach(p => {
      const pid = p.post_id || p._id.toString();
      p.comment_count = countMap.get(pid) || 0;
      if (checkUserId) {
        const isSaved = Array.isArray(p.saved_by) && p.saved_by.some(u => {
          if (!u) return false;
          const s = u.toString();
          return s === checkUserId || s === checkUid || (checkObjId && s === checkObjId.toString());
        });
        const isSupported = Array.isArray(p.supported_by) && p.supported_by.some(u => {
          if (!u) return false;
          const s = u.toString();
          return s === checkUserId || s === checkUid || (checkObjId && s === checkObjId.toString());
        });
        p.isSaved = isSaved;
        p.isSupported = isSupported;
        p.isLiked = isSupported;
      }
    });

    return res.status(200).json({
      success: true,
      data: posts.map(formatPost),
      pagination: {
        page,
        limit,
        totalPages,
        totalPosts
      }
    });
  } catch (error) {
    next(error);
  }
};

// 5. Create Post
const createPost = async (req, res, next) => {
  try {
    const { title, caption, hashtags, content, communityId, community_id, communityName, community_name, communityImage, community_image } = req.body;
    const finalCommunityId = communityId || community_id || null;
    const finalCommunityName = communityName || community_name || '';
    const finalCommunityImage = communityImage || community_image || '';

    if (!title || !title.trim()) {
      return errorResponse(res, 400, 'Title is required');
    }

    let parsedContent = [];
    if (content) {
      try {
        parsedContent = typeof content === 'string' ? JSON.parse(content) : content;
      } catch (_) {
        parsedContent = [];
      }
    }

    let coverImage = '';
    if (req.files && req.files.cover_image && req.files.cover_image.length > 0) {
      coverImage = req.files.cover_image[0].filename;
    } else if (req.file && req.file.fieldname === 'cover_image') {
      coverImage = req.file.filename;
    } else if (req.body.cover_image) {
      coverImage = req.body.cover_image;
    } else if (req.body.cover_img) {
      coverImage = req.body.cover_img;
    }

    let userId = req.user ? req.user._id : (req.body.user_id || null);
    const clientUsername = (req.body.username && req.body.username.trim() && req.body.username.trim() !== 'Anonymous')
      ? req.body.username.trim()
      : null;
    let username = clientUsername || (req.user ? (req.user.username || req.user.name) : null);
    let profileImage = req.body.profile_image || (req.user ? req.user.profileImage : '') || '';

    if ((!username || username === 'Anonymous' || username.match(/^[0-9a-fA-F]{24}$/)) && userId) {
      if (typeof userId === 'string' && userId.match(/^[0-9a-fA-F]{24}$/)) {
        const foundUser = await User.findById(userId);
        if (foundUser) {
          username = foundUser.username || foundUser.name || username;
          profileImage = profileImage || foundUser.profileImage || '';
        }
      } else {
        const foundUser = await User.findOne({
          $or: [
            { user_id: userId },
            { username: userId },
            { mobileNumber: userId }
          ]
        });
        if (foundUser) {
          username = foundUser.username || foundUser.name || username;
          profileImage = profileImage || foundUser.profileImage || '';
        }
      }
    }

    if (!username || username === 'Anonymous' || username.match(/^[0-9a-fA-F]{24}$/)) {
      username = 'Ryitu User';
    }

    if (!userId) {
      userId = new (require('mongoose').Types.ObjectId)();
    }

    // Retroactively update past anonymous or raw ID posts for this user
    if (userId && username && username !== 'Ryitu User' && username !== 'Anonymous') {
      Post.updateMany(
        {
          user_id: userId,
          $or: [
            { username: 'Anonymous' },
            { username: '' },
            { username: null },
            { username: 'Ryitu User' },
            { username: { $regex: /^[0-9a-fA-F]{24}$/ } }
          ]
        },
        { $set: { username, ...(profileImage ? { profile_image: profileImage } : {}) } }
      ).catch(() => {});
    }

    const post = await Post.create({
      user_id: userId,
      username,
      profile_image: profileImage,
      title: title.trim(),
      caption: caption ? caption.trim() : '',
      categoryId: 'CAT00000004', // Ryitu
      category: 'Ryitu',
      communityId: finalCommunityId,
      communityName: finalCommunityName,
      communityImage: finalCommunityImage,
      content: parsedContent,
      cover_image: coverImage,
      hashtags: hashtags || '',
      // Page count — number of pages in the story/PDF (sent from client)
      pageCount: parseInt(req.body.pageCount || req.body.page_count || '0', 10) || parsedContent.length || 0,
      pdf_url: req.body.pdf_url || req.body.pdfUrl || '',
      is_pdf: Boolean(req.body.is_pdf || req.body.isPdf),
    });

    return res.status(201).json({
      success: true,
      message: 'Story published successfully!',
      data: formatPost(post)
    });
  } catch (error) {
    next(error);
  }
};

// 6. Get Post By ID
const getPostById = async (req, res, next) => {
  try {
    const { id } = req.params;
    let post = null;
    if (id.match(/^[0-9a-fA-F]{24}$/)) {
      post = await Post.findById(id);
    }
    if (!post) {
      post = await Post.findOne({ post_id: id });
    }

    if (!post) {
      return errorResponse(res, 404, 'Story not found');
    }

    if (!post.username || post.username === 'Anonymous' || post.username.match(/^[0-9a-fA-F]{24}$/)) {
      if (post.user_id) {
        try {
          const conditions = [{ user_id: post.user_id }];
          if (typeof post.user_id === 'string' && post.user_id.match(/^[0-9a-fA-F]{24}$/)) {
            conditions.push({ _id: post.user_id });
          }
          const userDoc = await User.findOne({ $or: conditions }).select('username name profileImage');
          if (userDoc) {
            post.username = userDoc.username || userDoc.name || post.username;
            if (!post.profile_image && userDoc.profileImage) {
              post.profile_image = userDoc.profileImage;
            }
          }
        } catch (_) {}
      }
    }

    return res.status(200).json({
      success: true,
      data: formatPost(post)
    });
  } catch (error) {
    next(error);
  }
};

// 7. Delete Post
const deletePost = async (req, res, next) => {
  try {
    const { id } = req.params;
    let result = null;
    if (id.match(/^[0-9a-fA-F]{24}$/)) {
      result = await Post.findByIdAndDelete(id);
    }
    if (!result) {
      result = await Post.findOneAndDelete({ post_id: id });
    }
    return successResponse(res, 200, 'Story deleted successfully');
  } catch (error) {
    next(error);
  }
};

// 8. Toggle Support (Like)
const toggleSupport = async (req, res, next) => {
  try {
    const { id } = req.params;
    let post = null;
    if (id.match(/^[0-9a-fA-F]{24}$/)) {
      post = await Post.findById(id);
    }
    if (!post) {
      post = await Post.findOne({ post_id: id });
    }

    if (!post) {
      return errorResponse(res, 404, 'Post not found');
    }

    const userId = req.user ? req.user._id.toString() : (req.body.userId || req.body.user_id || req.query.userId || req.query.user_id || null);
    let isSupported = false;

    if (userId) {
      let uId = userId;
      let objId = null;
      if (typeof userId === 'string' && userId.match(/^[0-9a-fA-F]{24}$/)) {
        objId = new (require('mongoose').Types.ObjectId)(userId);
      } else {
        try {
          const user = await User.findOne({
            $or: [{ user_id: userId }, { username: userId }, { mobileNumber: userId }]
          });
          if (user) {
            uId = user._id.toString();
            objId = user._id;
          }
        } catch (_) {}
      }

      const idx = post.supported_by.findIndex(u => {
        if (!u) return false;
        const s = u.toString();
        return s === userId.toString() || s === uId.toString() || (objId && s === objId.toString());
      });

      if (idx !== -1) {
        post.supported_by.splice(idx, 1);
        post.support_count = Math.max(0, post.support_count - 1);
        isSupported = false;
      } else {
        post.supported_by.push(userId);
        post.support_count += 1;
        isSupported = true;
      }
      await post.save();
    }

    return successResponse(res, 200, 'Support toggled', {
      isSupported,
      support_count: post.support_count
    });
  } catch (error) {
    next(error);
  }
};

// 9. Toggle Save (Bookmark)
const toggleSave = async (req, res, next) => {
  try {
    const { id } = req.params;
    let post = null;
    if (id.match(/^[0-9a-fA-F]{24}$/)) {
      post = await Post.findById(id);
    }
    if (!post) {
      post = await Post.findOne({ post_id: id });
    }

    if (!post) {
      return errorResponse(res, 404, 'Post not found');
    }

    const userId = req.user ? req.user._id.toString() : (req.body.userId || req.body.user_id || req.query.userId || req.query.user_id || null);
    let isSaved = false;

    if (userId) {
      let uId = userId;
      let objId = null;
      if (typeof userId === 'string' && userId.match(/^[0-9a-fA-F]{24}$/)) {
        objId = new (require('mongoose').Types.ObjectId)(userId);
      } else {
        try {
          const user = await User.findOne({
            $or: [{ user_id: userId }, { username: userId }, { mobileNumber: userId }]
          });
          if (user) {
            uId = user._id.toString();
            objId = user._id;
          }
        } catch (_) {}
      }

      const isAlreadySaved = post.saved_by.some(u => {
        if (!u) return false;
        const s = u.toString();
        return s === userId.toString() || s === uId.toString() || (objId && s === objId.toString());
      });

      if (isAlreadySaved) {
        post.saved_by = post.saved_by.filter(u => {
          if (!u) return false;
          const s = u.toString();
          return s !== userId.toString() && s !== uId.toString() && (!objId || s !== objId.toString());
        });
        isSaved = false;
      } else {
        post.saved_by.push(userId);
        if (uId && uId !== userId && !post.saved_by.some(x => x && x.toString() === uId.toString())) {
          post.saved_by.push(uId);
        }
        isSaved = true;
      }
      await post.save();
    }

    return res.status(200).json({
      success: true,
      message: 'Save toggled',
      isSaved,
      data: { isSaved }
    });
  } catch (error) {
    next(error);
  }
};

// 10. Increment Views
const incrementView = async (req, res, next) => {
  try {
    const { id } = req.params;
    let query = id.match(/^[0-9a-fA-F]{24}$/) ? { _id: id } : { post_id: id };
    await Post.findOneAndUpdate(query, { $inc: { views: 1 } });
    return res.status(200).json({ success: true });
  } catch (error) {
    return res.status(200).json({ success: true });
  }
};

// 11. User Posts
const getUserPosts = async (req, res, next) => {
  try {
    const { userId } = req.params;
    let query = {};
    if (userId.match(/^[0-9a-fA-F]{24}$/)) {
      query.$or = [
        { user_id: userId },
        { user_id: new (require('mongoose').Types.ObjectId)(userId) }
      ];
    } else {
      const user = await User.findOne({
        $or: [{ user_id: userId }, { username: userId }, { mobileNumber: userId }]
      });
      if (user) {
        query.$or = [
          { user_id: user._id.toString() },
          { user_id: user._id },
          { user_id: userId }
        ];
      } else {
        query.$or = [
          { user_id: userId },
          { username: userId }
        ];
      }
    }

    const posts = await Post.find(query).sort({ createdAt: -1 });

    const postIds = posts.map(p => p.post_id || p._id.toString());
    const countMap = new Map();
    try {
      const commentCounts = await Comment.aggregate([
        { $match: { post_id: { $in: postIds } } },
        { $group: { _id: '$post_id', count: { $sum: 1 } } }
      ]);
      commentCounts.forEach(c => countMap.set(c._id, c.count));
    } catch (_) {}

    posts.forEach(p => {
      const pid = p.post_id || p._id.toString();
      p.comment_count = countMap.get(pid) || 0;
    });

    return res.status(200).json({
      success: true,
      data: posts.map(formatPost)
    });
  } catch (error) {
    next(error);
  }
};

// 12. Saved Posts
const getSavedPosts = async (req, res, next) => {
  try {
    const { userId } = req.params;
    let uId = userId;
    let objId = null;
    if (userId.match(/^[0-9a-fA-F]{24}$/)) {
      objId = new (require('mongoose').Types.ObjectId)(userId);
    }
    let foundUser = null;
    try {
      foundUser = await User.findOne({
        $or: [
          ...(objId ? [{ _id: objId }] : []),
          { user_id: userId },
          { username: userId },
          { mobileNumber: userId }
        ]
      });
      if (foundUser) {
        uId = foundUser._id.toString();
        objId = foundUser._id;
      }
    } catch (_) {}

    const filter = {
      $or: [
        { saved_by: userId },
        { saved_by: uId },
        ...(objId ? [{ saved_by: objId }] : []),
        ...(foundUser && foundUser.user_id ? [{ saved_by: foundUser.user_id }] : []),
        ...(foundUser && foundUser.mobileNumber ? [{ saved_by: foundUser.mobileNumber }] : [])
      ]
    };

    const posts = await Post.find(filter).sort({ createdAt: -1 });

    const postIds = posts.map(p => p.post_id || p._id.toString());
    const countMap = new Map();
    try {
      const commentCounts = await Comment.aggregate([
        { $match: { post_id: { $in: postIds } } },
        { $group: { _id: '$post_id', count: { $sum: 1 } } }
      ]);
      commentCounts.forEach(c => countMap.set(c._id, c.count));
    } catch (_) {}

    const formatted = posts.map(p => {
      const pid = p.post_id || p._id.toString();
      p.comment_count = countMap.get(pid) || 0;
      p.isSaved = true;
      return formatPost(p);
    });

    return res.status(200).json({
      success: true,
      data: formatted
    });
  } catch (error) {
    next(error);
  }
};

// 13. User Drafts
const getUserDrafts = async (req, res, next) => {
  try {
    const { userId } = req.params;
    let query = {};
    if (userId.match(/^[0-9a-fA-F]{24}$/)) {
      query.$or = [
        { user_id: userId },
        { user_id: new (require('mongoose').Types.ObjectId)(userId) }
      ];
    } else {
      const user = await User.findOne({
        $or: [{ user_id: userId }, { username: userId }, { mobileNumber: userId }]
      });
      if (user) {
        query.$or = [
          { user_id: user._id.toString() },
          { user_id: user._id },
          { user_id: userId }
        ];
      } else {
        query = { user_id: userId };
      }
    }

    const drafts = await Draft.find(query).sort({ createdAt: -1 });
    return res.status(200).json({
      success: true,
      data: drafts.map((d) => {
        const cover = d.cover_image || '';
        return {
          draft_id: d.draft_id || d._id.toString(),
          _id: d._id.toString(),
          id: d.draft_id || d._id.toString(),
          title: d.title,
          caption: d.caption,
          categoryId: 'CAT00000004',
          category: 'Ryitu',
          content: d.content,
          cover_image: cover,
          cover_img: cover,
          coverImage: cover,
          created_at: d.createdAt
        };
      })
    });
  } catch (error) {
    next(error);
  }
};

// 14. Get Comments for a Post
const getComments = async (req, res, next) => {
  try {
    const { postId } = req.params;
    const currentUserId = req.user ? req.user._id.toString() : (req.query.userId || req.query.user_id || null);

    let targetPostIds = [postId];
    try {
      const post = await Post.findOne({
        $or: [
          { post_id: postId },
          ...(postId && postId.match(/^[0-9a-fA-F]{24}$/) ? [{ _id: postId }] : [])
        ]
      });
      if (post) {
        if (post.post_id && !targetPostIds.includes(post.post_id)) targetPostIds.push(post.post_id);
        if (post._id && !targetPostIds.includes(post._id.toString())) targetPostIds.push(post._id.toString());
      }
    } catch (_) {}

    const comments = await Comment.find({ post_id: { $in: targetPostIds } }).sort({ createdAt: 1 });

    const topLevel = [];
    const repliesMap = new Map();

    comments.forEach(c => {
      const isLiked = Boolean(
        currentUserId && c.liked_by && c.liked_by.some(u => u && u.toString() === currentUserId.toString())
      );
      const commentObj = {
        _id: c._id.toString(),
        id: c._id.toString(),
        postId: c.post_id,
        post_id: c.post_id,
        userId: c.user_id?.toString() || '',
        user_id: c.user_id?.toString() || '',
        username: c.username || 'Ryitu User',
        profileImage: c.profile_image || '',
        profile_image: c.profile_image || '',
        avatarText: (c.username && c.username.trim()) ? c.username.trim()[0].toUpperCase() : 'U',
        text: c.text,
        message: c.text,
        comment: c.text,
        likesCount: c.likes_count || 0,
        likes_count: c.likes_count || 0,
        isLiked,
        createdAt: c.createdAt,
        parentCommentId: c.parent_comment_id || null,
        parent_comment_id: c.parent_comment_id || null,
        replies: []
      };

      if (c.parent_comment_id) {
        const list = repliesMap.get(c.parent_comment_id) || [];
        list.push(commentObj);
        repliesMap.set(c.parent_comment_id, list);
      } else {
        topLevel.push(commentObj);
      }
    });

    topLevel.forEach(tl => {
      tl.replies = repliesMap.get(tl.id) || [];
    });

    return res.status(200).json({
      success: true,
      count: comments.length,
      comments: topLevel,
      data: {
        count: comments.length,
        comments: topLevel
      }
    });
  } catch (error) {
    next(error);
  }
};

// 15. Add Comment to Post
const addComment = async (req, res, next) => {
  try {
    const { postId } = req.params;
    const { text, message, comment: commentBody, parent_comment_id, parentCommentId, user_id, userId, username, profile_image, profileImage } = req.body;
    const commentContent = (text || message || commentBody || '').toString().trim();

    if (!commentContent) {
      return errorResponse(res, 400, 'Comment text is required');
    }

    let targetPostId = postId;
    try {
      const post = await Post.findOne({
        $or: [
          { post_id: postId },
          ...(postId && postId.match(/^[0-9a-fA-F]{24}$/) ? [{ _id: postId }] : [])
        ]
      });
      if (post && post.post_id) {
        targetPostId = post.post_id;
      }
    } catch (_) {}

    let resolvedUserId = req.user ? req.user._id.toString() : (userId || user_id || 'USR00000001');
    let resolvedUsername = (username && username.trim() && username.trim() !== 'Anonymous')
      ? username.trim()
      : (req.user ? (req.user.username || req.user.name) : 'Ryitu User');
    let resolvedProfileImage = profileImage || profile_image || (req.user ? req.user.profileImage : '') || '';

    if ((!resolvedUsername || resolvedUsername === 'Ryitu User') && resolvedUserId) {
      try {
        const u = await User.findOne({
          $or: [
            ...(resolvedUserId.match(/^[0-9a-fA-F]{24}$/) ? [{ _id: resolvedUserId }] : []),
            { user_id: resolvedUserId },
            { username: resolvedUserId },
            { mobileNumber: resolvedUserId }
          ]
        });
        if (u) {
          resolvedUsername = u.username || u.name || resolvedUsername;
          resolvedProfileImage = resolvedProfileImage || u.profileImage || '';
        }
      } catch (_) {}
    }

    const parentId = parent_comment_id || parentCommentId || null;

    const comment = await Comment.create({
      post_id: targetPostId,
      user_id: resolvedUserId,
      username: resolvedUsername,
      profile_image: resolvedProfileImage,
      text: commentContent,
      parent_comment_id: parentId
    });

    const commentData = {
      _id: comment._id.toString(),
      id: comment._id.toString(),
      postId: comment.post_id,
      post_id: comment.post_id,
      userId: comment.user_id.toString(),
      user_id: comment.user_id.toString(),
      username: comment.username,
      profileImage: comment.profile_image,
      profile_image: comment.profile_image,
      avatarText: comment.username ? comment.username[0].toUpperCase() : 'U',
      text: comment.text,
      message: comment.text,
      comment: comment.text,
      likesCount: 0,
      likes_count: 0,
      isLiked: false,
      createdAt: comment.createdAt,
      parentCommentId: comment.parent_comment_id,
      parent_comment_id: comment.parent_comment_id,
      replies: []
    };

    return res.status(201).json({
      success: true,
      message: 'Comment added successfully',
      comment: commentData,
      data: commentData
    });
  } catch (error) {
    next(error);
  }
};

// 16. Toggle Comment Like
const toggleCommentLike = async (req, res, next) => {
  try {
    const { commentId } = req.params;
    const userId = req.user ? req.user._id.toString() : (req.body.userId || req.body.user_id || 'USR00000001');

    const comment = await Comment.findById(commentId);
    if (!comment) {
      return errorResponse(res, 404, 'Comment not found');
    }

    const idx = comment.liked_by.findIndex(u => u && u.toString() === userId.toString());
    let isLiked = false;
    if (idx !== -1) {
      comment.liked_by.splice(idx, 1);
      comment.likes_count = Math.max(0, comment.likes_count - 1);
      isLiked = false;
    } else {
      comment.liked_by.push(userId);
      comment.likes_count += 1;
      isLiked = true;
    }
    await comment.save();

    return successResponse(res, 200, 'Comment like toggled', {
      isLiked,
      likesCount: comment.likes_count
    });
  } catch (error) {
    next(error);
  }
};

// 17. Delete Comment
const deleteComment = async (req, res, next) => {
  try {
    const { commentId } = req.params;
    await Comment.findByIdAndDelete(commentId);
    await Comment.deleteMany({ parent_comment_id: commentId });
    return successResponse(res, 200, 'Comment deleted successfully');
  } catch (error) {
    next(error);
  }
};

module.exports = {
  extractDocument,
  getDocumentFull,
  getDocumentChunk,
  getPosts,
  createPost,
  getPostById,
  deletePost,
  toggleSupport,
  toggleSave,
  incrementView,
  getUserPosts,
  getSavedPosts,
  getUserDrafts,
  getComments,
  addComment,
  toggleCommentLike,
  deleteComment
};
