const Draft = require('../models/Draft');
const { cleanExtractedText } = require('../utils/textCleaner.util');
const { successResponse, errorResponse } = require('../utils/response.util');

// Helper to clean and autocorrect Tamil spelling and typography across all draft page blocks
const cleanContentPages = (content) => {
  if (!content) return content;
  if (Array.isArray(content)) {
    return content.map(page => {
      if (!page || typeof page !== 'object') return page;
      if (Array.isArray(page.blocks)) {
        return {
          ...page,
          blocks: page.blocks.map(b => {
            if (b && b.type === 'text' && typeof b.text === 'string' && b.text.trim()) {
              return { ...b, text: cleanExtractedText(b.text) };
            }
            return b;
          })
        };
      }
      return page;
    });
  } else if (content && typeof content === 'object') {
    if (Array.isArray(content.pages)) {
      return {
        ...content,
        pages: content.pages.map(page => {
          if (!page || typeof page !== 'object') return page;
          if (Array.isArray(page.blocks)) {
            return {
              ...page,
              blocks: page.blocks.map(b => {
                if (b && b.type === 'text' && typeof b.text === 'string' && b.text.trim()) {
                  return { ...b, text: cleanExtractedText(b.text) };
                }
                return b;
              })
            };
          }
          return page;
        })
      };
    }
  }
  return content;
};

const saveDraft = async (req, res, next) => {
  try {
    const { draftId, draft_id, title, caption, content, user_id } = req.body;
    let userId = req.user ? req.user._id : (user_id || null);
    if (!userId) {
      userId = new (require('mongoose').Types.ObjectId)();
    }

    const cleanedTitle = title ? cleanExtractedText(title).trim() : '';
    const cleanedCaption = caption ? cleanExtractedText(caption).trim() : '';

    let parsedContent = [];
    if (content) {
      if (typeof content === 'string') {
        const trimmed = content.trim();
        if (trimmed.isNotEmpty || trimmed.length > 0) {
          try {
            parsedContent = JSON.parse(trimmed);
          } catch (_) {
            parsedContent = [{
              fontSize: 22,
              fontFamily: 'Mukta Malar',
              fontColor: 0xFF000000,
              lineSpacing: 1.4,
              letterSpacing: 0.0,
              pageMargin: 50.0,
              textAlign: 0,
              blocks: [{ type: 'text', text: cleanExtractedText(trimmed) }]
            }];
          }
        }
      } else {
        parsedContent = content;
      }
    }
    parsedContent = cleanContentPages(parsedContent);

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

    const targetDraftId = draftId || draft_id;
    let draft = null;
    if (targetDraftId) {
      if (typeof targetDraftId === 'string' && targetDraftId.match(/^[0-9a-fA-F]{24}$/)) {
        draft = await Draft.findById(targetDraftId);
      }
      if (!draft) {
        draft = await Draft.findOne({ draft_id: targetDraftId });
      }
    }

    if (draft) {
      draft.title = cleanedTitle || draft.title;
      draft.caption = cleanedCaption || draft.caption;
      if (parsedContent && (Array.isArray(parsedContent) ? parsedContent.length > 0 : true)) {
        draft.content = parsedContent;
        draft.markModified('content');
      }
      draft.category = 'Ryitu';
      if (coverImage) draft.cover_image = coverImage;
      await draft.save();
    } else {
      draft = await Draft.create({
        user_id: userId,
        title: cleanedTitle || 'Untitled Draft',
        caption: cleanedCaption || '',
        categoryId: 'CAT00000004',
        category: 'Ryitu',
        content: parsedContent,
        cover_image: coverImage
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Draft saved successfully',
      draftId: draft.draft_id,
      draft_id: draft.draft_id,
      content: draft.content,
      cover_image: draft.cover_image,
      cover_img: draft.cover_image,
      data: draft
    });
  } catch (error) {
    next(error);
  }
};

const deleteDraft = async (req, res, next) => {
  try {
    const { id } = req.params;
    let result = null;
    if (id.match(/^[0-9a-fA-F]{24}$/)) {
      result = await Draft.findByIdAndDelete(id);
    }
    if (!result) {
      result = await Draft.findOneAndDelete({ draft_id: id });
    }
    return successResponse(res, 200, 'Draft deleted successfully');
  } catch (error) {
    next(error);
  }
};

module.exports = {
  saveDraft,
  deleteDraft
};
