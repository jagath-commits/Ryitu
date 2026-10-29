/**
 * tamilExtractionPipeline.util.js
 *
 * Unified 3-Layer Tamil PDF Text Extraction Pipeline
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Layer 1: Unicode text extraction
 *   Extract text directly from the PDF's content stream using pdf-parse /
 *   pdfjs. Works for PDFs that contain valid Unicode Tamil or English text.
 *   Preserves Tamil characters, pulli, vowel signs, combined characters,
 *   paragraph breaks and reading order as faithfully as possible.
 *
 * Layer 2: Legacy Tamil encoding detection and conversion
 *   For older PDFs using font-specific encodings (Bamini, Softland/CP1252,
 *   MacRoman/TSCII, Anjal, Inaimathi), detect the likely encoding from the
 *   extracted text and embedded font names, then apply a verified converter.
 *   Delegates to the existing cleanExtractedText() pipeline in
 *   textCleaner.util.js which implements all supported conversions.
 *
 * Layer 3: Scanned-page Tamil OCR
 *   When Layer 1 + Layer 2 produce no usable text (blank page, image-only
 *   scan), render the PDF page as an image and run Tesseract.js OCR using
 *   the tam+eng trained data.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Selection logic (per page):
 *   1. Extract raw text via pdf-parse getTextContent().
 *   2. Assess quality (confidence score, legacy indicators, font names).
 *   3a. High confidence (≥0.75) → Layer 1 only, minimal cleaning.
 *   3b. Medium / legacy indicators → Layer 2 (legacy conversion pipeline).
 *   3c. Empty / very low confidence + likely scanned → Layer 3 (OCR).
 *   4. Validate result; if still unusable, return status with a clear message.
 *
 * Assumptions / requirements:
 *   - pdf-parse@2.4.5 (PDFParse class) — already in package.json
 *   - tesseract.js@7.0.0 — already in package.json
 *   - tam.traineddata + eng.traineddata — already at backend root
 *   - pdfjs-dist@5.x — already installed (used for page rendering to canvas)
 *   - canvas npm package for Node.js server-side rendering
 *     (if not installed, OCR falls back to returning null gracefully)
 *
 * pdfjs-dist canvas rendering note:
 *   pdfjs-dist v5 requires the 'canvas' npm package for Node.js rendering.
 *   Install with: npm install canvas
 *   If canvas is unavailable, OCR layer gracefully degrades (returns null /
 *   'ocr_unavailable' status rather than crashing).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const path = require('path');
const { cleanExtractedText, isTamilDocumentOrPassage } = require('./textCleaner.util');
const { assessTextQuality, isTextUsable, isLikelyScannedPage } = require('./pageTextQuality.util');
const { recogniseImage, isOcrAvailable } = require('./ocrEngine.util');

// ─── Canvas availability check (needed for pdfjs-dist page rendering) ─────────
let canvasAvailable = false;
let pdfjsLib = null;

try {
  require('canvas'); // will throw if not installed
  pdfjsLib = require('pdfjs-dist/legacy/build/pdf.js');
  canvasAvailable = true;
} catch (_) {
  // canvas or pdfjs-dist/legacy not available — OCR image rendering disabled
  // OCR layer will be skipped gracefully
}

// ─── Coordinate-aware text reconstruction (copied + enhanced from book.controller) ─

/**
 * Reconstruct text from a pdfjs TextContent object.
 * Groups glyph fragments by line using Y coordinates, then joins them with
 * appropriate spacing. Prevents artificial spaces before Tamil combining
 * characters (pulli, vowel signs).
 *
 * @param {Object} tc  TextContent from page.getTextContent()
 * @returns {string}
 */
function extractTextFromTextContent(tc) {
  if (!tc || !Array.isArray(tc.items) || tc.items.length === 0) return '';

  const items = tc.items
    .filter(it => it && typeof it.str === 'string')
    .map(it => {
      const tx = it.transform || [1, 0, 0, 1, 0, 0];
      return {
        str: it.str,
        x: tx[4],
        y: tx[5],
        width: it.width || 0,
        height: it.height || Math.abs(tx[3]) || 12,
        fontName: it.fontName || ''
      };
    });

  if (items.length === 0) return '';

  // Sort: Y descending (top to bottom in PDF coords), then X ascending
  items.sort((a, b) => {
    const yDiff = b.y - a.y;
    return Math.abs(yDiff) > 4 ? yDiff : a.x - b.x;
  });

  // Group into lines by Y proximity
  const lines = [];
  let currentLine = [];
  let currentY = items[0].y;
  let avgHeight = items[0].height || 12;

  for (const item of items) {
    if (Math.abs(item.y - currentY) > avgHeight * 0.6) {
      if (currentLine.length > 0) {
        lines.push({ y: currentY, items: currentLine });
      }
      currentLine = [item];
      currentY = item.y;
      avgHeight = item.height || avgHeight;
    } else {
      currentLine.push(item);
    }
  }
  if (currentLine.length > 0) {
    lines.push({ y: currentY, items: currentLine });
  }

  // Reconstruct paragraphs
  const resultParagraphs = [];
  let currentParagraph = '';
  let prevLineY = null;

  for (const line of lines) {
    line.items.sort((a, b) => a.x - b.x);

    let lineText = '';
    let prevItem = null;

    for (const item of line.items) {
      if (!prevItem) {
        lineText += item.str;
      } else {
        const gap = item.x - (prevItem.x + prevItem.width);
        // Do not insert space before Tamil combining characters (pulli, vowel signs)
        const isCombiningChar = /^[\u0BBE-\u0BCD\u0BD7]/.test(item.str);
        if (gap > 2.5 && !isCombiningChar && !prevItem.str.endsWith(' ') && !item.str.startsWith(' ')) {
          lineText += ' ' + item.str;
        } else {
          lineText += item.str;
        }
      }
      prevItem = item;
    }

    if (prevLineY !== null) {
      const lineGap = prevLineY - line.y;
      if (lineGap > avgHeight * 1.8) {
        if (currentParagraph) {
          resultParagraphs.push(currentParagraph.trim());
        }
        currentParagraph = lineText;
      } else {
        currentParagraph += (currentParagraph ? ' ' : '') + lineText;
      }
    } else {
      currentParagraph = lineText;
    }
    prevLineY = line.y;
  }

  if (currentParagraph) {
    resultParagraphs.push(currentParagraph.trim());
  }

  return resultParagraphs.join('\n\n');
}

/**
 * Collect unique font names from TextContent items.
 * @param {Object} tc
 * @returns {string[]}
 */
function collectFontNames(tc) {
  if (!tc || !Array.isArray(tc.items)) return [];
  const seen = new Set();
  for (const item of tc.items) {
    if (item.fontName) seen.add(item.fontName);
  }
  return [...seen];
}

// ─── PDF page → image (for OCR) ──────────────────────────────────────────────

/**
 * Render a PDF page to a PNG Buffer using pdfjs-dist + canvas.
 * Returns null if canvas / pdfjs-dist rendering is unavailable.
 *
 * @param {Buffer} pdfBuffer
 * @param {number} pageNum  1-based
 * @returns {Promise<Buffer | null>}
 */
async function renderPageToImageBuffer(pdfBuffer, pageNum) {
  if (!canvasAvailable || !pdfjsLib) return null;

  let doc = null;
  try {
    const { createCanvas } = require('canvas');

    // pdfjs-dist v5 Node.js API
    const loadingTask = pdfjsLib.getDocument({
      data: new Uint8Array(pdfBuffer),
      useWorkerFetch: false,
      isEvalSupported: false,
      useSystemFonts: true
    });

    doc = await loadingTask.promise;
    const page = await doc.getPage(pageNum);

    const SCALE = 2.0; // 2× for better OCR accuracy
    const viewport = page.getViewport({ scale: SCALE });
    const canvas = createCanvas(Math.round(viewport.width), Math.round(viewport.height));
    const ctx = canvas.getContext('2d');

    // White background (Tesseract works better on white)
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    await page.render({
      canvasContext: ctx,
      viewport
    }).promise;

    const pngBuffer = canvas.toBuffer('image/png');
    page.cleanup();
    return pngBuffer;
  } catch (err) {
    console.warn('[Pipeline] Page render error (page', pageNum + '):', err.message);
    return null;
  } finally {
    if (doc) {
      try { await doc.destroy(); } catch (_) {}
    }
  }
}

// ─── Count images on a pdf-lib page (for scanned-page detection) ─────────────

/**
 * Attempt to count embedded XObject images on a page using pdf-lib.
 * Returns 0 on any error (non-critical hint only).
 *
 * @param {Object} pdfLibPage  A page object from PDFDocument.getPage()
 * @returns {number}
 */
function countPageImages(pdfLibPage) {
  try {
    const { PDFName } = require('pdf-lib');
    const resources = pdfLibPage.node.Resources();
    if (!resources) return 0;
    const xObject = resources.lookup(PDFName.of('XObject'));
    if (!xObject) return 0;
    let count = 0;
    for (const [, ref] of xObject.entries()) {
      try {
        const obj = pdfLibPage.doc.context.lookup(ref);
        if (obj && obj.dict) {
          const subtype = obj.dict.lookup(PDFName.of('Subtype'));
          if (subtype && subtype.encodedName === '/Image') count++;
        }
      } catch (_) {}
    }
    return count;
  } catch (_) {
    return 0;
  }
}

// ─── Main pipeline ────────────────────────────────────────────────────────────

/**
 * @typedef {Object} ExtractionResult
 * @property {string}  text                Clean extracted text (may be empty)
 * @property {string}  method              'unicode' | 'legacy_converted' | 'ocr' | 'empty' | 'error'
 * @property {number}  confidence          0.0–1.0
 * @property {boolean} isTamil             Whether Tamil content was detected
 * @property {string}  [warning]           Optional warning for the caller
 * @property {string}  [rawText]           Raw unprocessed text (for debugging)
 * @property {string[]} fontNames          Font names found on page
 */

/**
 * Extract text from a single PDF page using the 3-layer pipeline.
 *
 * @param {Object} options
 * @param {Object}   options.pdfParseDoc      pdf-parse PDFParse doc (already loaded)
 * @param {Buffer}   options.pdfBuffer        Raw PDF file buffer (for OCR rendering)
 * @param {number}   options.pageNum          1-based page number
 * @param {Object}   [options.pdfLibPage]     pdf-lib page (for image count hinting)
 * @param {boolean}  [options.skipOcr]        Skip Layer 3 even when applicable
 * @returns {Promise<ExtractionResult>}
 */
async function extractPageText({ pdfParseDoc, pdfBuffer, pageNum, pdfLibPage = null, skipOcr = false }) {
  let rawText = '';
  let fontNames = [];

  // ── Layer 1: Unicode extraction ──────────────────────────────────────────
  // pdf-parse API: pdfParseDoc.doc.getPage(n) → pageObj
  //                pdfParseDoc.getPageText(pageObj, {}) → string
  try {
    const pageObj = await pdfParseDoc.doc.getPage(pageNum);

    // Try getPageText first (preserves reading order in some PDFs)
    // Note: pdf-parse v2 getPageText returns a plain string, not {text: ...}
    try {
      const pageResult = await pdfParseDoc.getPageText(pageObj, {});
      if (typeof pageResult === 'string' && pageResult.trim().length > 0) {
        rawText = pageResult;
      }
    } catch (_) {}

    // Always collect font names from TextContent (lightweight call)
    try {
      const tc = await pageObj.getTextContent();
      fontNames = collectFontNames(tc);

      // Fallback: coordinate-aware layout extraction when getPageText returned nothing
      if (!rawText || rawText.trim().length === 0) {
        rawText = extractTextFromTextContent(tc);
      }
    } catch (_) {}

    pageObj.cleanup();
  } catch (pageErr) {
    console.warn(`[Pipeline] Layer 1 error on page ${pageNum}:`, pageErr.message);
  }

  // ── Quality assessment ───────────────────────────────────────────────────
  const quality = assessTextQuality(rawText, fontNames);

  // ── Layer 2: Legacy encoding conversion ──────────────────────────────────
  let processedText = rawText;
  let method = 'unicode';

  if (quality.isEmpty) {
    method = 'empty';
  } else if (quality.recommendation === 'use_as_is') {
    // Layer 1 text is good — still run through cleanExtractedText for
    // typography normalisation (pulli, kerning, paragraph reflow) but
    // the legacy decoders inside will detect no legacy signatures and skip.
    processedText = cleanExtractedText(rawText);
    method = 'unicode';
  } else if (quality.recommendation === 'apply_legacy_conversion') {
    // Layer 2: run the full legacy conversion pipeline
    processedText = cleanExtractedText(rawText);
    method = 'legacy_converted';

    // Post-conversion sanity check
    if (!isTextUsable(processedText)) {
      // Conversion may have made things worse — revert to raw if raw was better
      if (isTextUsable(rawText)) {
        processedText = rawText;
        method = 'unicode';
      } else {
        // Both raw and converted are unusable — OCR candidate
        method = 'empty';
        processedText = '';
      }
    }
  } else if (quality.recommendation === 'try_ocr') {
    method = 'empty'; // will be overridden by OCR below
    processedText = '';
  }

  // ── Layer 3: OCR fallback ─────────────────────────────────────────────────
  const imageCount = pdfLibPage ? countPageImages(pdfLibPage) : 0;
  const needsOcr =
    !skipOcr &&
    isOcrAvailable() &&
    (method === 'empty' || isLikelyScannedPage(rawText, imageCount)) &&
    processedText.trim().length < 10;

  let ocrWarning = null;

  if (needsOcr) {
    if (!canvasAvailable) {
      ocrWarning = 'OCR skipped: canvas package not installed. Install with: npm install canvas';
      console.warn('[Pipeline]', ocrWarning);
    } else {
      try {
        const imageBuffer = await renderPageToImageBuffer(pdfBuffer, pageNum);
        if (imageBuffer) {
          const ocrResult = await recogniseImage(imageBuffer);
          if (ocrResult && ocrResult.text && ocrResult.text.trim().length >= 5) {
            // Run OCR output through the cleaning pipeline too (OCR text may have
            // legacy encoding artifacts in some edge cases, and always benefits
            // from typography normalisation)
            processedText = cleanExtractedText(ocrResult.text);
            method = 'ocr';

            if (ocrResult.confidence < 0.5) {
              ocrWarning = `OCR confidence is low (${(ocrResult.confidence * 100).toFixed(0)}%). Manual review recommended for this page.`;
            }
          } else {
            ocrWarning = 'OCR produced no usable text for this page. The page may be blank or the image quality too low.';
          }
        } else {
          ocrWarning = 'Could not render page to image for OCR.';
        }
      } catch (ocrErr) {
        ocrWarning = `OCR error: ${ocrErr.message}`;
        console.error('[Pipeline] OCR error on page', pageNum, ':', ocrErr.message);
      }
    }
  }

  // ── Final isTamil check ───────────────────────────────────────────────────
  const isTamil = isTamilDocumentOrPassage(processedText) || isTamilDocumentOrPassage(rawText);

  // ── Confidence for final result ───────────────────────────────────────────
  let finalConfidence = quality.confidence;
  if (method === 'legacy_converted') {
    // Conversion may have improved quality — re-assess
    const postQuality = assessTextQuality(processedText);
    finalConfidence = Math.max(quality.confidence, postQuality.confidence * 0.9);
  } else if (method === 'ocr') {
    finalConfidence = 0.6; // OCR is generally lower certainty
  } else if (method === 'empty') {
    finalConfidence = 0;
  }

  return {
    text: processedText.trim(),
    method,
    confidence: Math.round(finalConfidence * 100) / 100,
    isTamil,
    warning: ocrWarning,
    fontNames,
    rawText: process.env.NODE_ENV === 'development' ? rawText : undefined
  };
}

/**
 * Extract text from all pages of a PDF and combine them in page order.
 * Each page is processed independently so mixed PDFs are handled correctly.
 *
 * @param {Object} options
 * @param {Object}  options.pdfParseDoc   pdf-parse PDFParse doc (loaded)
 * @param {Buffer}  options.pdfBuffer     Raw PDF buffer
 * @param {number}  options.startPage     First page to process (1-based)
 * @param {number}  options.endPage       Last page to process (inclusive)
 * @param {Object}  [options.pdfLibDoc]   pdf-lib PDFDocument (optional, for image counting)
 * @param {boolean} [options.skipOcr]     Skip Layer 3
 * @returns {Promise<{pages: ExtractionResult[], combined: string, summary: Object}>}
 */
async function extractAllPages({ pdfParseDoc, pdfBuffer, startPage = 1, endPage, pdfLibDoc = null, skipOcr = false }) {
  const totalPages = pdfParseDoc.doc ? pdfParseDoc.doc.numPages : (endPage || startPage);
  const last = endPage || totalPages;

  const pages = [];
  const methodCounts = { unicode: 0, legacy_converted: 0, ocr: 0, empty: 0, error: 0 };

  for (let p = startPage; p <= last; p++) {
    let pdfLibPage = null;
    if (pdfLibDoc) {
      try { pdfLibPage = pdfLibDoc.getPage(p - 1); } catch (_) {}
    }

    let result;
    try {
      result = await extractPageText({ pdfParseDoc, pdfBuffer, pageNum: p, pdfLibPage, skipOcr });
    } catch (err) {
      result = {
        text: '',
        method: 'error',
        confidence: 0,
        isTamil: false,
        warning: `Extraction error: ${err.message}`,
        fontNames: []
      };
    }

    result.page = p;
    pages.push(result);
    methodCounts[result.method] = (methodCounts[result.method] || 0) + 1;
  }

  // Combine text with page separators
  const combined = pages
    .map(p => p.text)
    .filter(t => t && t.trim().length > 0)
    .join('\n\n');

  const summary = {
    totalPages: last - startPage + 1,
    methodCounts,
    hasOcrPages: methodCounts.ocr > 0,
    hasLegacyPages: methodCounts.legacy_converted > 0,
    hasEmptyPages: methodCounts.empty > 0
  };

  return { pages, combined, summary };
}

module.exports = {
  extractPageText,
  extractAllPages,
  extractTextFromTextContent,
  // Exposed for testing
  collectFontNames,
  renderPageToImageBuffer,
  countPageImages
};

