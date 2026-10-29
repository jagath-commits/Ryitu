/**
 * ocrEngine.util.js
 *
 * Layer 3: Scanned-page Tamil OCR using Tesseract.js v7.
 *
 * Requirements:
 *   - tesseract.js v7+ (already in package.json)
 *   - tam.traineddata  (already present at backend root)
 *   - eng.traineddata  (already present at backend root)
 *
 * The worker is created lazily on first OCR call and terminated when
 * the server shuts down (or the module is unloaded in tests).
 *
 * Configuration:
 *   - OCR_LANG: 'tam+eng' (Tamil + English combined, handles mixed pages)
 *   - Trained data path: backend root directory (where tam.traineddata lives)
 *   - Page segmentation mode: PSM.AUTO_OSD (automatic detection of page layout)
 *
 * Notes:
 *   - Tesseract.js v7 loads traineddata from a local path via langPath option.
 *   - OCR is CPU-intensive. It is only called when Layers 1 and 2 fail to
 *     produce usable text (i.e. isLikelyScannedPage or very low confidence).
 *   - A per-call timeout (OCR_TIMEOUT_MS) prevents hangs on bad pages.
 *   - If OCR fails (timeout / error), the function returns null so the caller
 *     can fall back to an appropriate error state.
 */

'use strict';

const path = require('path');
const Tesseract = require('tesseract.js');

// Path to the directory that contains tam.traineddata and eng.traineddata
const TRAINED_DATA_DIR = path.resolve(__dirname, '../../');

// Language: Tamil + English so mixed content pages work
const OCR_LANG = 'tam+eng';

// Maximum time to wait for OCR on a single page (ms)
const OCR_TIMEOUT_MS = 60_000; // 60 s — scanned pages can be slow

// Minimum acceptable character count from OCR before we declare the result empty
const MIN_OCR_CHARS = 5;

/** @type {Tesseract.Worker | null} */
let _worker = null;
let _workerReady = false;
let _initPromise = null;

/**
 * Initialize (or return existing) Tesseract worker.
 * @returns {Promise<Tesseract.Worker>}
 */
async function getWorker() {
  if (_worker && _workerReady) return _worker;
  if (_initPromise) return _initPromise;

  _initPromise = (async () => {
    try {
      _worker = await Tesseract.createWorker(OCR_LANG, 1, {
        langPath: TRAINED_DATA_DIR,
        // Silence Tesseract's verbose progress logs in production
        logger: process.env.NODE_ENV === 'development'
          ? (m) => { if (m.status === 'recognizing text') process.stdout.write('.'); }
          : undefined,
        errorHandler: (err) => {
          console.error('[OCR] Tesseract worker error:', err?.message || err);
        }
      });
      _workerReady = true;
      console.log('[OCR] Tesseract worker initialized with', OCR_LANG);
      return _worker;
    } catch (err) {
      _initPromise = null;
      _workerReady = false;
      _worker = null;
      throw err;
    }
  })();

  return _initPromise;
}

/**
 * Terminate the Tesseract worker (call on server shutdown).
 */
async function terminateWorker() {
  if (_worker) {
    try {
      await _worker.terminate();
    } catch (_) {}
    _worker = null;
    _workerReady = false;
    _initPromise = null;
  }
}

/**
 * Perform OCR on an image buffer (PNG/JPEG) and return the recognised text.
 *
 * @param {Buffer | string} imageSource  Image buffer or file path to OCR
 * @returns {Promise<{text: string, confidence: number} | null>}
 *   Returns null if OCR failed or timed out.
 */
async function recogniseImage(imageSource) {
  let worker;
  try {
    worker = await getWorker();
  } catch (initErr) {
    console.error('[OCR] Failed to initialise worker:', initErr.message);
    return null;
  }

  try {
    const resultPromise = worker.recognize(imageSource);

    // Apply timeout
    const timeoutPromise = new Promise((_, reject) =>
      setTimeout(() => reject(new Error('OCR timeout')), OCR_TIMEOUT_MS)
    );

    const { data } = await Promise.race([resultPromise, timeoutPromise]);

    const text = (data.text || '').trim();
    const confidence = data.confidence != null ? data.confidence / 100 : 0; // normalise 0–100 → 0–1

    if (text.length < MIN_OCR_CHARS) {
      return { text: '', confidence: 0 };
    }

    return { text, confidence };
  } catch (ocrErr) {
    if (ocrErr.message === 'OCR timeout') {
      console.warn('[OCR] Recognition timed out after', OCR_TIMEOUT_MS, 'ms');
    } else {
      console.error('[OCR] Recognition error:', ocrErr.message);
    }
    return null;
  }
}

/**
 * Check whether OCR is available (trained data files exist).
 *
 * @returns {boolean}
 */
function isOcrAvailable() {
  const fs = require('fs');
  const tamPath = path.join(TRAINED_DATA_DIR, 'tam.traineddata');
  const engPath = path.join(TRAINED_DATA_DIR, 'eng.traineddata');
  return fs.existsSync(tamPath) && fs.existsSync(engPath);
}

module.exports = {
  recogniseImage,
  terminateWorker,
  isOcrAvailable,
  OCR_LANG,
  OCR_TIMEOUT_MS
};

