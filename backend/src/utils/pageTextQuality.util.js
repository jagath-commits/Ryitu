/**
 * pageTextQuality.util.js
 *
 * Confidence scoring and quality assessment for extracted PDF text.
 *
 * Used by the 3-layer Tamil extraction pipeline to decide whether extracted
 * text is usable, needs legacy conversion, or needs OCR fallback.
 *
 * Does NOT modify or correct text — only observes and scores it.
 */

'use strict';

// Tamil Unicode block U+0B80–U+0BFF
const TAMIL_UNICODE_RE = /[\u0B80-\u0BFF]/g;
const TAMIL_CONSONANTS_RE = /[\u0B95-\u0BB9]/g;
const TAMIL_VOWEL_SIGNS_RE = /[\u0BBE-\u0BCD\u0BD7]/g;
const ENGLISH_ALPHA_RE = /[a-zA-Z]/g;

// Characters that strongly suggest legacy/mojibake encoding (not normal Unicode prose)
const LEGACY_INDICATOR_RE = /[\u0080-\u009F\u0152\u0153\u017D\u017E\u01AB\u01AC\u0192\u201A\u201E\u20AC\u2020\u2021\xA2\xA3\xA7\xA9\xAA\xAB\xAC\xAF\xB2\xB4\xB6\xB8\xBA\xBB]/g;

// MacRoman / TSCII distinctive characters
const MACROMAN_RE = /[æÒΩß∫Ú¡ÛÃÕ‹Ô‡›⁄˙˛ÌØÓÉ˚ıˆ˝∏≈¢ª√®±÷◊∆∑]/g;

// Bamini-style ASCII patterns: consonant letter followed by semicolon
const BAMINI_RE = /[fqrQljegkaytospwdcSH];|fs;/g;

// Replacement characters (U+FFFD) — extraction failure markers
const REPLACEMENT_CHAR_RE = /\uFFFD/g;

/**
 * Count regex matches in a string (non-destructive).
 */
function countMatches(text, re) {
  const matches = text.match(new RegExp(re.source, re.flags.replace('g', '') + 'g'));
  return matches ? matches.length : 0;
}

/**
 * Assess the quality of extracted text from a single PDF page.
 *
 * Returns a score object:
 * {
 *   confidence:      number  0.0–1.0 (1.0 = definitely good Unicode text)
 *   tamilRatio:      number  fraction of non-space chars that are Tamil Unicode
 *   englishRatio:    number  fraction of non-space chars that are ASCII alpha
 *   legacyScore:     number  0–1 likelihood of legacy encoding presence
 *   macRomanScore:   number  0–1 likelihood of MacRoman/TSCII encoding
 *   baminiScore:     number  0–1 likelihood of Bamini ASCII encoding
 *   replacementCount:number  count of U+FFFD replacement characters
 *   isEmpty:         boolean true if text has no meaningful content
 *   recommendation:  string  'use_as_is' | 'apply_legacy_conversion' | 'try_ocr' | 'empty'
 *   details:         string  human-readable explanation
 * }
 *
 * @param {string} rawText  Raw text as extracted by pdf-parse / getTextContent()
 * @param {string[]} [fontNames]  Font names found on this page (optional hint)
 */
function assessTextQuality(rawText, fontNames = []) {
  const text = (rawText || '').trim();
  const textLen = text.length;
  const nonSpaceLen = text.replace(/\s/g, '').length;

  // Empty page
  if (textLen < 3 || nonSpaceLen < 2) {
    return {
      confidence: 0,
      tamilRatio: 0,
      englishRatio: 0,
      legacyScore: 0,
      macRomanScore: 0,
      baminiScore: 0,
      replacementCount: 0,
      isEmpty: true,
      recommendation: 'empty',
      details: 'No meaningful text extracted from page'
    };
  }

  const tamilCount = countMatches(text, TAMIL_UNICODE_RE);
  const engCount = countMatches(text, ENGLISH_ALPHA_RE);
  const legacyCount = countMatches(text, LEGACY_INDICATOR_RE);
  const macRomanCount = countMatches(text, MACROMAN_RE);
  const baminiCount = countMatches(text, BAMINI_RE);
  const replacementCount = countMatches(text, REPLACEMENT_CHAR_RE);

  const tamilRatio = nonSpaceLen > 0 ? tamilCount / nonSpaceLen : 0;
  const englishRatio = nonSpaceLen > 0 ? engCount / nonSpaceLen : 0;

  // Compute legacy likelihood scores (0–1)
  const legacyScore = Math.min(1, legacyCount / Math.max(1, nonSpaceLen) * 20);
  const macRomanScore = Math.min(1, macRomanCount / Math.max(1, nonSpaceLen) * 15);
  const baminiScore = Math.min(1, baminiCount / Math.max(1, textLen) * 10);

  // Font name hints
  const fontStr = fontNames.join(' ').toLowerCase();
  const hasBaminiFont = /bamini|baamini/.test(fontStr);
  const hasLegacyTamilFont = /tscii|anjal|inaimathi|tam\b|softland|shree|latha|muktaMalar|karumbi/i.test(fontStr);
  const hasUnicodeFont = /unicode|opentype|noto|lohit|gentium|ariel|arial|calibri|times/i.test(fontStr);

  // ------ Confidence calculation ------
  // Start at 1.0 and penalise for signs of problems

  let confidence = 1.0;

  // Penalty: replacement characters are a clear extraction failure
  if (replacementCount > 0) {
    confidence -= Math.min(0.6, replacementCount / Math.max(1, nonSpaceLen) * 30);
  }

  // Penalty: high ratio of legacy/mojibake characters
  if (legacyScore > 0.05) {
    confidence -= Math.min(0.4, legacyScore * 0.8);
  }

  // Penalty: MacRoman characters mixed with non-Tamil text
  if (macRomanScore > 0.05) {
    confidence -= Math.min(0.5, macRomanScore * 0.9);
  }

  // Penalty: Bamini-style patterns
  if (baminiScore > 0.05 || hasBaminiFont) {
    confidence -= Math.min(0.5, baminiScore * 0.9 + (hasBaminiFont ? 0.2 : 0));
  }

  // Penalty: text that is almost entirely non-Tamil non-English (random symbols)
  const meaningfulRatio = tamilRatio + englishRatio;
  if (meaningfulRatio < 0.15 && nonSpaceLen > 10) {
    confidence -= Math.min(0.5, (0.15 - meaningfulRatio) * 5);
  }

  // Penalty: very high proportion of replacement chars
  if (replacementCount / Math.max(1, nonSpaceLen) > 0.3) {
    confidence = Math.min(confidence, 0.1);
  }

  // Bonus: clean Tamil Unicode with good vowel-sign ratios
  if (tamilCount > 5) {
    const consonantCount = countMatches(text, TAMIL_CONSONANTS_RE);
    const vowelSignCount = countMatches(text, TAMIL_VOWEL_SIGNS_RE);
    // Healthy Tamil text has ~0.5–2.0 vowel signs per consonant
    if (consonantCount > 0) {
      const vowelToConsonant = vowelSignCount / consonantCount;
      if (vowelToConsonant >= 0.4 && vowelToConsonant <= 3.0) {
        confidence += 0.05; // Small bonus for well-formed Tamil
      }
    }
  }

  confidence = Math.max(0, Math.min(1, confidence));

  // ------ Recommendation ------
  let recommendation;
  let details;

  if (confidence >= 0.75) {
    // Text looks clean — apply minimal post-processing only
    recommendation = 'use_as_is';
    details = `High-confidence text (score=${confidence.toFixed(2)}). Tamil ratio=${(tamilRatio * 100).toFixed(1)}%, English ratio=${(englishRatio * 100).toFixed(1)}%.`;
  } else if (confidence >= 0.35 || legacyScore > 0.05 || macRomanScore > 0.05 || baminiScore > 0.05 || hasBaminiFont || hasLegacyTamilFont) {
    // Likely legacy encoding — try conversion
    recommendation = 'apply_legacy_conversion';
    details = `Possible legacy encoding detected (score=${confidence.toFixed(2)}, legacy=${legacyScore.toFixed(2)}, macRoman=${macRomanScore.toFixed(2)}, bamini=${baminiScore.toFixed(2)}). Applying conversion pipeline.`;
  } else if (confidence < 0.35 && nonSpaceLen > 5) {
    // Very low quality — try OCR
    recommendation = 'try_ocr';
    details = `Low-confidence extraction (score=${confidence.toFixed(2)}). Replacement chars=${replacementCount}. OCR fallback recommended.`;
  } else {
    recommendation = 'use_as_is';
    details = `Borderline quality (score=${confidence.toFixed(2)}). Using as extracted.`;
  }

  return {
    confidence,
    tamilRatio,
    englishRatio,
    legacyScore,
    macRomanScore,
    baminiScore,
    replacementCount,
    isEmpty: false,
    recommendation,
    details
  };
}

/**
 * Check whether the cleaned text is usable (sufficient Tamil or English content).
 * Used as a post-conversion sanity check.
 *
 * @param {string} text  Cleaned/converted text
 * @returns {boolean}
 */
function isTextUsable(text) {
  if (!text || text.trim().length < 5) return false;
  const nonSpace = text.replace(/\s/g, '').length;
  if (nonSpace < 3) return false;

  const tamilCount = countMatches(text, TAMIL_UNICODE_RE);
  const engCount = countMatches(text, ENGLISH_ALPHA_RE);
  const digits = (text.match(/\d/g) || []).length;
  const meaningful = tamilCount + engCount + digits;

  // At least 20% of non-space chars should be recognisable script
  return nonSpace > 0 && (meaningful / nonSpace) >= 0.20;
}

/**
 * Detect whether a page is likely scanned (image-based).
 *
 * Heuristic: if pdf-lib page has a very large image XObject and text
 * extraction yields near-zero content, it is likely scanned.
 *
 * @param {string} rawText  Raw extracted text
 * @param {number} imageCount  Number of images detected on the page (from pdf-lib)
 * @returns {boolean}
 */
function isLikelyScannedPage(rawText, imageCount = 0) {
  const len = (rawText || '').trim().length;
  // If no text at all and at least one image, very likely scanned
  if (len < 5 && imageCount >= 1) return true;
  // If extremely sparse text relative to a document page, probably scanned
  if (len < 20 && imageCount >= 1) return true;
  return false;
}

module.exports = {
  assessTextQuality,
  isTextUsable,
  isLikelyScannedPage
};

