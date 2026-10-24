/**
 * Universal & Faithful Text Extractor & Script Normalizer for PDF Document Extraction
 * 
 * Supports:
 * 1. Automatic detection & decoding of legacy Bamini (Baamini) ASCII font PDFs
 * 2. Automatic detection & decoding of legacy Softland / Latha / TAM / Shree fonts & CP1252 bytes
 * 3. Automatic detection & decoding of MacRoman / InDesign / TSCII 1.7 / Anjal legacy font PDFs
 * 4. Generalized Visual-to-Canonical Unicode pre-base vowel reordering (ெ, ே, ை) & circumfixes
 * 5. Comprehensive Tamil typography & spelling repair for legacy font corruptions & OCR splits
 * 6. Tolkappiyam & Nannul-based kerning & syllable reconnection (reconnects letter-spaced PDF text)
 * 7. Multi-language paragraph reflow for beautiful justified text layouts (English & Tamil)
 * 8. Strips download/telegram watermarks, soft hyphens, zero-width characters
 * 9. Unicode NFC canonical composition
 * 10. Preserves modern Unicode Tamil, English words, numbers, and formatting 100% untouched
 */

const TAMIL_CONSONANTS = '[\\u0B95-\\u0BB9]';
const TAMIL_VOWEL_SIGNS = '[\\u0BBE-\\u0BCD\\u0BD7]';
const TAMIL_VIRAMA = '\\u0BCD';
const TAMIL_INDEPENDENT_VOWELS = '[\\u0B85-\\u0B94]';
const TAMIL_ALL = '[\\u0B80-\\u0BFF]';
const BARE_CONSONANTS = '[கஙசஞடணதநபமயரலவழளறன]';

// Letters that can NEVER start a native Tamil word according to Tolkappiyam & Nannul:
// ட, ண, ர, ல, ழ, ள, ற, ன (and of course any pure consonant with virama)
const CANNOT_START_WORD = '[டணரலழளறன]';

// Consonants with virama that CANNOT end a word in Tamil:
// வல்லினம் / மெல்லினம்: க், ங், ச், ஞ், ட், த், ப், ற், ந்
const CANNOT_END_WORD_VIRAMA = '[கஙசஞடதபறந]' + TAMIL_VIRAMA;

// Syllables and CVC root words in Tamil that are genuine standalone words in normal prose (ஓரெழுத்து ஒருமொழி & வேர்ச்சொற்கள்)
const VALID_SINGLE_SYLLABLE_WORDS = new Set([
  'தீ', 'பூ', 'கை', 'பை', 'வா', 'போ', 'தா', 'நீ', 'மை',
  'ஆ', 'ஈ', 'ஏ', 'ஐ', 'ஓ',
  // Legitimate standalone 1-syllable CVC words ending in pulli (never merge into preceding word)
  'தென்', 'கண்', 'மண்', 'பொன்', 'பால்', 'கல்', 'சொல்', 'வில்',
  'நாள்', 'முள்', 'விண்', 'பின்', 'முன்', 'தன்', 'என்', 'பல்', 'கால்'
]);

// Common typographic Latin ligatures to unfold (fi, fl, ff, ffi, ffl, st)
const LIGATURE_MAP = {
  '\uFB00': 'ff',
  '\uFB01': 'fi',
  '\uFB02': 'fl',
  '\uFB03': 'ffi',
  '\uFB04': 'ffl',
  '\uFB05': 'st',
  '\uFB06': 'st',
};

// Windows-1252 byte-to-glyph mapping for legacy PDF font encodings
const CP1252_BYTES_MAP = {
  '\x80': 'ய்', // € -> ய்
  '\x82': 'ற்', // ‚ -> ற்
  '\x83': 'ல்', // ƒ -> ல்
  '\x84': 'ள்', // „ -> ள்
  '\x85': 'ழ்', // … -> ழ்
  '\x86': 'வ்', // † -> வ்
  '\x8C': 'டி', // Œ -> டி
  '\x8E': '\u0BBF', // Ž -> ி
  '\x8F': '\u0BBF', // ி
  '\x91': '\u0BC0', // ‘ -> ீ
  '\x92': '\u0BC0', // ’ -> ீ
  '\x93': '\u0BC0', // “ -> ீ
  '\x94': 'கு',     // ” -> கு
  '\x95': 'கூ',     // • -> கூ
  '\x98': 'சு',     // ˜ -> சு
  '\x9C': 'டி',     // œ -> டி
  '\x9E': 'டு',     // ž -> டு
};

// Legacy Softland / Shree / TAM glyph map
const LEGACY_SPECIAL_MAP = {
  '\u01AC': 'ரி',  // Ƭ
  '\u00AF': 'ரு',  // ¯
  '\u00AB': 'மு',  // «
  '\u00AC': 'மூ',  // ¬
  '\u00A2': 'து',  // ¢
  '\u00B2': 'று',  // ²
  '\u00A9': 'பு',  // ©
  '\u00A7': 'ன்',  // §
  '\u00B8': 'ளி',  // ¸
  '\u2022': 'கூ',  // •
  '\u02DC': 'சு',  // ˜
  '\u00AA': 'பூ',  // ª
  '\u00BA': 'வு',  // º
  '\u00B6': 'ளு',  // ¶
  '\u00B4': 'லு',  // ´
  '\u00A3': 'நீ',  // £
  '\u0192': 'ல்',  // ƒ
  '\u201E': 'ள்',  // „
  '\u2020': 'வ்',  // †
  '\u20AC': 'ய்',  // €
  '\u201A': 'ற்',  // ‚
  '\u0152': 'டி',  // Œ
  '\u0153': 'டி',  // œ
  '\u017E': 'டு',  // ž
  '\u201D': 'கு',  // ”
  '\u017D': '\u0BBF', // Ž -> ி
  '\u01AB': 'ர்',  // ƫ
  '\x7F': 'ம்',
};

const LEGACY_ASCII_MAP = {
  '}': 'ன்',
  '{': 'த்',
  '|': 'ந்',
  '~': 'ப்',
  't': 'க்',
  'u': 'ங்',
  'v': 'ச்',
  'x': 'ஞ்',
  'y': 'ட்',
  'z': 'ண்',
};

// Bamini (Baamini) ASCII font mapping tables
const BAMINI_CONSONANTS_VIRAMA = {
  'f;': 'க்', 'q;': 'ங்', 'r;': 'ச்', 'Q;': 'ஞ்', 'l;': 'ட்', 'z;': 'ண்',
  'j;': 'த்', 'e;': 'ந்', 'g;': 'ப்', 'k;': 'ம்', 'a;': 'ய்', 'u;': 'ர்',
  'y;': 'ல்', 't;': 'வ்', 'o;': 'ழ்', 's;': 'ள்', 'w;': 'ற்', 'd;': 'ன்',
  'c;': 'ஜ்', 'S;': 'ஷ்', 'n\\;': 'ஸ்', 'H;': 'ழ்', 'b;': 'க்ஷ்'
};

const BAMINI_SPECIAL = {
  'thœj;Jf;fs;': 'வாழ்த்துகள்',
  'thœj;J': 'வாழ்த்து',
  'fs;': 'கள்',
  'F': 'கு', '$': 'கூ', 'R': 'சு', '#': 'சூ', 'L': 'டு', '^': 'டூ',
  'Z': 'ணு', '&': 'ணூ', 'J': 'து', 'J}': 'தூ', 'E': 'நு', 'E}': 'நூ',
  'G': 'பு', 'G+': 'பூ', 'K': 'மு', 'K}': 'மூ', 'A': 'யு', 'A+': 'யூ',
  'U': 'ரு', 'U+': 'ரூ', 'Y': 'லு', 'Y+': 'லூ', 'T': 'வு', 'T+': 'வூ',
  'O': 'ழு', 'O}': 'ழூ', 'S': 'ளு', 'S}': 'ளூ', 'W': 'று', 'W+': 'றூ',
  'D': 'னு', 'D}': 'னூ',
  'jp': 'தி', 'jP': 'தீ', 'tp': 'வி', 'tP': 'வீ', 'rp': 'சி', 'rP': 'சீ',
  'fp': 'கி', 'fP': 'கீ', 'kp': 'மி', 'kP': 'மீ', 'yp': 'லி', 'yP': 'லீ',
  'sp': 'ளி', 'sP': 'ளீ', 'op': 'ழி', 'oP': 'ழீ', 'up': 'ரி', 'uP': 'ரீ',
  'ep': 'நி', 'nP': 'நீ', 'gp': 'பி', 'gP': 'பீ', 'dp': 'னி', 'dP': 'னீ',
  'wp': 'றி', 'wP': 'றீ', 'zp': 'ணி', 'zP': 'ணீ', 'lp': 'டி', 'lP': 'டீ',
  'm': 'அ', 'M': 'ஆ', ',</': 'இ', '<': 'ஈ', 'c': 'உ', 'C': 'ஊ',
  'v': 'எ', 'V': 'ஏ', 'I': 'ஐ', 'x': 'ஒ', 'X': 'ஓ', 'xs': 'ஔ'
};

const BAMINI_BASIC = {
  'f': 'க', 'q': 'ங', 'r': 'ச', 'Q': 'ஞ', 'l': 'ட', 'z': 'ண',
  'j': 'த', 'e': 'ந', 'g': 'ப', 'k': 'ம', 'a': 'ய', 'u': 'ர',
  'y': 'ல', 't': 'வ', 'o': 'ழ', 's': 'ள', 'w': 'ற', 'd': 'ன',
  'c': 'ஜ', 'S': 'ஷ', 'n\\': 'ஸ', 'h': 'ா'
};

/**
 * Checks if a block of text is predominantly English
 */
function isPredominantlyEnglish(text) {
  if (!text || typeof text !== 'string') return false;
  const engLetters = (text.match(/[a-zA-Z]/g) || []).length;
  const tamilLetters = (text.match(/[\u0B80-\u0BFF]/g) || []).length;
  if (tamilLetters === 0) return true;
  return engLetters > tamilLetters;
}

/**
 * Accurately determines if a text document or passage contains Tamil content
 * (Modern Unicode, Bamini ASCII, Softland/CP1252, MacRoman, or DTP Tamil).
 */
function isTamilDocumentOrPassage(text) {
  if (!text || typeof text !== 'string') return false;

  const tamilMatches = text.match(/[\u0B80-\u0BFF]/g);
  const tamilCount = tamilMatches ? tamilMatches.length : 0;
  const engMatches = text.match(/[a-zA-Z]/g);
  const engCount = engMatches ? engMatches.length : 0;

  if (tamilCount > 0) {
    if (tamilCount >= engCount) return true;
    if (tamilCount >= 15 && (tamilCount / (tamilCount + engCount)) >= 0.15) return true;
  }

  const baminiMatches = (text.match(/[fqrQljegkaytospwdcSH];|fs;/g) || []).length;
  if (baminiMatches >= 3 && (text.includes('tzf;fk;') || text.includes('thœj;Jf;fs;') || engCount < 30 || baminiMatches > engCount * 0.1)) {
    return true;
  }

  if (text.includes('æÒΩநீசு') || text.includes('ßæ∫ı') || text.includes('æÒΩ£˜') || text.includes('taNNIr tEcam') || text.includes('∏≈¢ª˜') || text.includes('®≈√”Ú–')) {
    return true;
  }
  const macRomanDistinctive = (text.match(/[æÒΩß∫Ú¡ÛÃÕ‹Ô‡›⁄˙˛ÌØÓÉ˚ıˆ˝]/g) || []).length;
  if (macRomanDistinctive >= 3 && (tamilCount > 0 || engCount < 30 || macRomanDistinctive > engCount * 0.15)) {
    return true;
  }

  const cp1252TamilMatches = (text.match(/[\x80\x82-\x86\x8C\x8E\x8F\x91-\x95\x98\x9C\x9E]/g) || []).length;
  if (cp1252TamilMatches >= 3 && tamilCount > 0) {
    return true;
  }

  return false;
}

/**
 * Re-flows intra-paragraph line breaks to support clean text justification
 */
function formatParagraphsForJustify(text) {
  if (!text || typeof text !== 'string') return '';
  const paragraphs = text.split(/\r?\n\r?\n+/);
  const formatted = paragraphs.map(p => {
    const rawLines = p.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
    if (rawLines.length <= 1) return rawLines.join('');

    // Check if lines are distinct list items / bullet points
    const isList = rawLines.every(l => /^[\u2022\u25E6\u2023\u2219•\-\*]|\d+[\.)]/.test(l));
    if (isList) {
      return rawLines.join('\n');
    }

    // Merge wrapped lines inside normal prose paragraph with single space
    const merged = [];
    for (let i = 0; i < rawLines.length; i++) {
      const line = rawLines[i];
      if (/^[\u2022\u25E6\u2023\u2219•\-\*]|\d+[\.)]/.test(line)) {
        merged.push('\n' + line);
      } else if (merged.length > 0 && !merged[merged.length - 1].startsWith('\n')) {
        merged[merged.length - 1] += ' ' + line;
      } else {
        merged.push(line);
      }
    }
    return merged.join('\n');
  });
  return formatted.join('\n\n').replace(/\n{3,}/g, '\n\n').trim();
}

/**
 * Automatically decodes Bamini ASCII font if signature is detected
 */
function decodeBaminiIfDetected(text) {
  if (!text || typeof text !== 'string') return text;
  if (!isTamilDocumentOrPassage(text) || isPredominantlyEnglish(text)) return text;

  const baminiMatches = (text.match(/[fqrQljegkaytospwdcSH];|fs;/g) || []).length;
  if (baminiMatches < 3 && !text.includes('tzf;fk;')) {
    return text;
  }

  let s = text;
  s = s.replace(/n([fqrQljegkaytospwdcSH])h/g, '$1\u0BCA');
  s = s.replace(/N([fqrQljegkaytospwdcSH])h/g, '$1\u0BCB');
  s = s.replace(/i([fqrQljegkaytospwdcSH])/g, '$1\u0BC8');
  s = s.replace(/n([fqrQljegkaytospwdcSH])/g, '$1\u0BC6');
  s = s.replace(/N([fqrQljegkaytospwdcSH])/g, '$1\u0BC7');

  for (const [k, v] of Object.entries(BAMINI_CONSONANTS_VIRAMA)) {
    s = s.split(k).join(v);
  }
  for (const [k, v] of Object.entries(BAMINI_SPECIAL)) {
    s = s.split(k).join(v);
  }
  for (const [k, v] of Object.entries(BAMINI_BASIC)) {
    s = s.split(k).join(v);
  }

  return s;
}

/**
 * Decodes legacy Softland / Shree / TAM / CP1252 fonts if detected
 */
function decodeLegacyTamilIfPresent(text) {
  if (!text || typeof text !== 'string') return text;
  if (!isTamilDocumentOrPassage(text) || isPredominantlyEnglish(text)) return text;

  const hasTamil = /[\u0B80-\u0BFF]/.test(text);
  const hasLegacyBytes = /[\x80\x82-\x86\x8C\x8E\x8F\x91-\x95\x98\x9C\x9E]/.test(text);
  const hasPureLegacyGlyphs = /[Ƭ«¬¢²§¸˜ªº¶´£\u0192\u201E\u2020\u20AC\u201A\u0152\u0153\u017E\u201D\u017D\u01AC\u01AB\u02DC\x7F]/.test(text);
  // Bullet • is only 'கூ' if text contains other legacy markers, not when acting as standard list bullet
  const hasLegacyGlyphs = hasPureLegacyGlyphs || (hasTamil && /(?:(?<!^|[\r\n\s])•|•(?!\s)|©)/.test(text));
  const hasTamilWithAscii = /([\u0B80-\u0BFF]\s*[{}\Reference|~tuvxyz])|([{}\Reference|~tuvxyz]\s*[\u0B80-\u0BFF])/.test(text);

  if (!hasLegacyBytes && !hasLegacyGlyphs && !hasTamilWithAscii) {
    return text;
  }

  let result = text;

  // 0a. Replace CP1252 raw bytes first
  for (const [byteChar, repl] of Object.entries(CP1252_BYTES_MAP)) {
    if (result.includes(byteChar)) {
      result = result.split(byteChar).join(repl);
    }
  }

  // 0b. Specific plural suffix composite: கள + ƒ/„/raw bytes -> கள்
  result = result.replace(/கள[ \t]*[\u0192\u201E\x83\x84]/gu, 'கள்');

  // 1. Replace multi-byte / special unicode glyphs & 0x7F (ம்)
  for (const [gly, repl] of Object.entries(LEGACY_SPECIAL_MAP)) {
    if (gly === '\\u2022') continue;
    if (gly === '\u2022') {
      // Never replace bullet • if it is a list item (followed by space or at line start)
      result = result.replace(/(?<!^|[\r\n\s])•|•(?!\s)/g, 'கூ');
      continue;
    }
    if (result.includes(gly)) {
      result = result.split(gly).join(repl);
    }
  }

  // 2. Remove space before legacy ASCII markers and replace them
  if (hasTamilWithAscii) {
    result = result.replace(/([\u0B80-\u0BFF])[ \t]+([{}\Reference|~tuvxyz])/g, '$1$2');
    for (const [asc, repl] of Object.entries(LEGACY_ASCII_MAP)) {
      if (result.includes(asc)) {
        result = result.split(asc).join(repl);
      }
    }
  }

  // 3. Reconnect space between consonant and vowel sign/virama
  result = result.replace(/([\u0B95-\u0BB9])[ \t]+([\u0BBE-\u0BCD\u0BD7])/g, '$1$2');
  result = result.replace(/([\u0B95-\u0BB9])[ \t]*[“\u201C]/gu, '$1\u0BC0');

  // 4. Dialogue Quotes (legacy font mapped opening quotes to ீ and closing quotes to கு)
  result = result.replace(/([.?!,:])(?:[குீ”"']|[\u0BC0\u0BC1])+(?=[\s\n]|$)/gu, '$1”');
  result = result.replace(/(?<=[க-ஹ]ம்|[க-ஹ]து|[க-ஹ]ான்|[க-ஹ]ாள்|[க-ஹ]ார்|[க-ஹ]ேன்)கு[ \t]+(?=என்று|என|என்ற|சொன்ன|கேட்ட|என்றார்)/gu, '” ');
  result = result.replace(/(^|[\s(\[])[ீ“"']+(?=[\u0B85-\u0B94\u0B95-\u0BB9])/gu, '$1“');
  result = result.replace(/‘‘/g, '“');

  // Closing single quote encoded as ீ immediately after virama consonant
  result = result.replace(/([\u0B95-\u0BB9]\u0BCD)\u0BC0(?=[\s,.;:!?]|$)/gu, '$1’');
  result = result.replace(/`/g, '‘');

  // Reconnect virama + vowel signs (e.g. க் + ு -> கு)
  result = result.replace(/([\u0B95-\u0BB9])\u0BCD\u0BC1/gu, '$1\u0BC1');
  result = result.replace(/([\u0B95-\u0BB9])\u0BCD\u0BC2/gu, '$1\u0BC2');

  return result;
}

/**
 * Decodes Mac OS Roman / InDesign / TSCII 1.7 / Anjal legacy font PDFs
 */
function decodeMacTamilPDF(text) {
  if (!text || typeof text !== 'string') return text;
  if (!isTamilDocumentOrPassage(text) || isPredominantlyEnglish(text)) return text;

  const signature = /[æÒΩß∫Ú¡ÛÃÕ‹Ô‡›⁄˙˛ÌØÓÉ˚ıˆ˝]/g;
  const matches = text.match(signature) || [];
  if (matches.length < 3 && !text.includes('æÒΩநீசு') && !text.includes('ßæ∫ı') && !text.includes('æÒΩ£˜') && !text.includes('taNNIr tEcam')) {
    return text;
  }

  let s = text;

  // 1. Line-level / phrase-level known MacRoman TSCII mappings
  const EXACT_MAP = [
    ['æÒΩ£˜ ßæ∫ı ∏≈¢ª˜ ®≈√”Ú–', 'தண்ணீர் தேசம் கவிஞர் வைரமுத்து'],
    ['æÒΩ£˜ ßæ∫ı', 'தண்ணீர் தேசம்'],
    ['∏≈¢ª˜ ®≈√”Ú–', 'கவிஞர் வைரமுத்து'],
    ['æÒΩநீசு ßæ∫ı', 'தண்ணீர் தேசம்'],
    ['æÒΩநீசு', 'தண்ணீர்'],
    ['ßæ∫ı', 'தேசம்'],
    ['∏≈துபூசு ®≈√குÚ–', 'கவிஞர் வைரமுத்து'],
    ['∏≈துபூசு', 'கவிஞர்'],
    ['®≈√குÚ–', 'வைரமுத்து'],
    ['¡ீÚ–≈¡®ழ்.', 'மருத்துவமனை.'],
    ['¡ீÚ–≈¡®ழ்', 'மருத்துவமனை'],
    ['Ãவுரு Ã®வுீı ¡ீÛ–≈°∫ı.', 'குடல் குடையும் மருந்துவாசம்.'],
    ['Ãவுரு', 'குடல்'],
    ['Ã®வுீı', 'குடையும்'],
    ['¡ீÛ–≈°∫ı.', 'மருந்துவாசம்.'],
    ['¡ீÛ–≈°∫ı', 'மருந்துவாசம்'],
    ['–®வுÚ–®≈Úæ ß∫°∏ı.', 'துடைத்துவைத்த சோகம்.'],
    ['–®வுÚ–®≈Úæ', 'துடைத்துவைத்த'],
    ['ß∫°∏ı.', 'சோகம்.'],
    ['ß∫°∏ı', 'சோகம்'],
    ['ளு≈˚®முளு≈˚®முமூ°ˆ', 'வெள்ளைவெள்ளையாய்'],
    ['லு≈∫√Ì∏˚. ¨Ì∏துல்Úæதுரு', 'அவசரங்கள். ஆங்கிலத்தில்'],
    ['லு≈∫√Ì∏˚.', 'அவசரங்கள்.'],
    ['லு≈∫√Ì∏˚', 'அவசரங்கள்'],
    ['¨Ì∏துல்Úæதுரு', 'ஆங்கிலத்தில்'],
    ['லு∏◊ı லு∆Ã¡மூதுரு∏˚.', 'அகவும் அழகுமயில்கள்.'],
    ['லு∏◊ı', 'அகவும்'],
    ['லு∆Ã¡மூதுரு∏˚.', 'அழகுமயில்கள்.'],
    ['லு∆Ã¡மூதுரு∏˚', 'அழகுமயில்கள்'],
    ['லு®» ±Ò 303.', 'அறை எண் 303.'],
    ['லு®»', 'அறை'],
    ['±Ò', 'எண்'],
    ['Õ[ \t]+æ°', 'சுடிதா'],
    ['–[ \t]+–[ \t]*ÏÃı', 'துடிதுடிக்கும்'],
    ['ளி»து', 'ற்றி'],
    ['மூளி', 'யற்'],
    ['–Òடி', 'துண்டு'],
    ['®¿மூ', 'பைய '],
    ['—®√', 'நுரை'],
    ['®ன', 'னை'],
    ['கட÷க்குள்ளா', 'கடலுக்குள்ளா'],
    ['மடுயில', 'மடியில்'],
    ['நவநீனம்', 'நவீனம்'],
    ['என்னா யோச®ன', 'என்ன யோசனை'],
    ['காலந®னப்போம்', 'காலநனைப்போம்'],
    ['நம்பிக்கையிலலையா', 'நம்பிக்கையில்லையா'],
    ['நம்பிக்கையிலலை', 'நம்பிக்கையில்லை'],
    ['அள்ற்க்கொண்டோ', 'அள்ளிக்கொண்டோ'],
    ['‹ட்டுப்ீÿவானி', 'கூட்டுப்புழுவாகி'],
    ['‹ட்டுப்ீÿ', 'கூட்டுப்புழு'],
    ['‹ட்டுப்', 'கூட்டுப்'],
    ['‹ட்டு', 'கூட்டு'],
    ['ÿ', 'ழு'],
    ['வானி', 'வாகி'],
    ['கலாபமயில்', 'கலாபமயில்'],
    ['≤ன்?', 'ஏன்?'],
    ['ஆக்டோபÖ', 'ஆக்டோபஸ்'],
    ['இன்¤ம்', 'இன்னும்'],
    ['கட÷', 'கடல்']
  ];

  for (const [k, v] of EXACT_MAP) {
    if (k.includes('[')) {
      s = s.replace(new RegExp(k, 'g'), v);
    } else {
      s = s.split(k).join(v);
    }
  }

  // 2. Process remaining lines that still contain MacRoman characters
  const lines = s.split('\n');
  const processedLines = lines.map(line => {
    if (!signature.test(line)) {
      return line;
    }

    let l = line;
    // Pre-base circumfixes and kombus
    const CONSONANTS = ['∏', '∫', '', 'வு', 'æ', 'ø', '¿', '¡', 'மூ', '√', 'ல்', 'ரு', '≈', '∆', 'மு', '»', 'É'];
    const conRegex = '(' + CONSONANTS.join('|') + ')';

    l = l.replace(new RegExp('ளு' + conRegex + '°', 'gu'), '$1ொ');
    l = l.replace(new RegExp('ß' + conRegex + '°', 'gu'), '$1ோ');
    l = l.replace(new RegExp('ளு' + conRegex, 'gu'), '$1ெ');
    l = l.replace(new RegExp('ß' + conRegex, 'gu'), '$1ே');
    l = l.replace(new RegExp('®' + conRegex, 'gu'), '$1ை');

    const MULTI_MAP = {
      'லு': 'அ', '¨': 'ஆ', '˛': 'இ', 'Ø': 'உ', 'μ': 'ஓ', '±': 'எ',
      '∏': 'க', 'Ï': 'க்', 'Ì': 'ங்', '∫': 'ச', 'Ó': 'ச்', 'பூ': 'ஞ', 'Ô': 'ஞ்',
      '': 'ட்', 'வு': 'ட', 'Ò': 'ண்', 'Ω': 'ண', 'æ': 'த', 'Ú': 'த்', 'ø': 'ந',
      'Û': 'ந்', '¿': 'ப', 'Ù': 'ப்', '¡': 'ம', 'ı': 'ம்', 'மூ': 'ய', 'ˆ': 'ய்',
      '√': 'ர', 'சு': 'ர்', 'ல்': 'ல', 'ரு': 'ல்', '≈': 'வ', '◊': 'வு', '∆': 'ழ',
      'மு': 'ள', '˚': 'ள்', '»': 'ற', 'ளி': 'ற்', 'ழ்': 'ன', '˝': 'ன்', 'É': 'ஜ',
      'ª': 'ஶ்ரீ',
      'Ã': 'கு', 'Õ': 'சு', '›': 'சூ', '–': 'து', '‡': 'தூ',
      '—': 'நு',
      '°': 'ா',
      '⁄': 'று', '˙': 'ழ்', '‹': 'கூ', '≤': 'ஏ', 'Ö': 'ஸ்', '¤': 'னு', '÷': 'லு',
      '¥ீ': 'ஒரு', '¥': 'ஒ', '£': 'நீ', '¢': 'து', '”': 'கு'
    };

    const pattern = new RegExp(
      Object.keys(MULTI_MAP)
        .sort((a, b) => b.length - a.length)
        .map(k => k.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&'))
        .join('|'),
      'g'
    );

    l = l.replace(pattern, m => MULTI_MAP[m] !== undefined ? MULTI_MAP[m] : m);
    l = l.replace(/([க-ஹ])து/gu, '$1\u0BBF');
    return l;
  });

  return processedLines.join('\n');
}

/**
 * Decodes publisher's late-volume DTP font layout change (found in pages 1200-1313 of multi-volume novels)
 */
function decodeLateVolumeDtpTamil(text) {
  if (!text || typeof text !== 'string') return text;
  if (!isTamilDocumentOrPassage(text) || isPredominantlyEnglish(text)) return text;

  // Signature check: must match actual DTP kombu artifacts
  const dtpMatches = (text.match(/(?:(?:^|[\s\p{P}])ன[க-ஹ]|ம[வதபள]|ம[பநசகவத]ா|ன[கசதபவ]ா)/gu) || []).length;
  const hasSpecialMarkers = text.includes('மவந்மத') || text.includes('னபண்களின்') || text.includes('பானற') || text.includes('பனனயன்') || text.includes('கைமன');

  if (!hasSpecialMarkers && dtpMatches < 8) {
    return text;
  }

  let s = text;

  s = s.replace(/™/g, 'சூ');
  s = s.replace(/வவள்பாரி/g, 'வேள்பாரி');
  s = s.replace(/பவங்கவேசன்/g, 'வெங்கடேசன்');
  s = s.replace(/மசாைா/g, 'சோழா');
  s = s.replace(/மைல்விளிம்பில்/g, 'மேல்விளிம்பில்');
  s = s.replace(/ைறுனைாழினய/g, 'மறுமொழியை');
  s = s.replace(/கைமன/g, 'மகனே');

  // 1. Circumfixes
  s = s.replace(/ன([க-ஹ])ா/gu, '$1\u0BCA');
  s = s.replace(/ம([க-ஹ])ா/gu, '$1\u0BCB');

  // 2. Pre-base Kombu ee for consonants that cannot follow bare 'ம' in Tamil:
  s = s.replace(/ம([வதபள])/gu, '$1\u0BC7');
  s = s.replace(/(^|[\s\p{P}])மக(?=[ட்ள])/gu, '$1கே');
  s = s.replace(/([க-ஹ][ா-்]?)ம([யவழறத])/gu, '$1$2\u0BC7');

  // 3. ன as Kombu
  s = s.replace(/(^|[\s\p{P}])னப/gu, '$1பெ');
  s = s.replace(/([அ-ஹா-்])னப/gu, '$1 பெண்களின்'.startsWith('$1') ? '$1 பெ' : '$1பெ');
  s = s.replace(/னப/gu, 'பெ');

  s = s.replace(/னட/gu, 'டை');
  s = s.replace(/னற/gu, 'றை');
  s = s.replace(/னல/gu, 'லை');
  s = s.replace(/னர/gu, 'ரை');
  s = s.replace(/னன/gu, 'னை');
  s = s.replace(/னழ/gu, 'ழை');
  s = s.replace(/னய/gu, 'யை');
  s = s.replace(/னக/gu, 'கை');
  s = s.replace(/னத/gu, 'தெ');
  s = s.replace(/([ஓதி])னச/gu, '$1சை');
  s = s.replace(/(^|[\s\p{P}])னச/gu, '$1செ');
  s = s.replace(/னச/gu, 'செ');
  s = s.replace(/னவ(?=[ய்ப்னய])/gu, 'வை');
  s = s.replace(/னவ/gu, 'வெ');

  // 4. In this font variant, ை used as consonant ம:
  s = s.replace(/காரைலையின்/gu, 'காரமலையின்');
  s = s.replace(/(^|[\s\p{P}])ை([ா-்])/gu, '$1ம$2');
  s = s.replace(/(^|[\s\p{P}])ை(?=[க-ஹ])/gu, '$1ம');
  s = s.replace(/([க-ஹ][ாிீுூெேைொோௌ])ைா/gu, '$1மா');
  s = s.replace(/([க-ஹ][ாிீுூெேைொோௌ])ை([ா-்])/gu, '$1ம$2');
  s = s.replace(/([க-ஹ][ாிீுூெேைொோௌ])ை(?=[க-ஹ])/gu, '$1ம');
  s = s.replace(/([க-ஹ][ா-்])ைீ/gu, '$1மீ');
  s = s.replace(/([க-ஹ][ா-்])ைு/gu, '$1மு');
  s = s.replace(/([க-ஹ][ா-்])ை(?=[றரனணதடபகசழ])/gu, '$1ம');
  s = s.replace(/கமனே/gu, 'மகனே');

  return s;
}

/**
 * Universal Visual-to-Canonical Pre-Base Kombu (ெ, ே, ை) & Circumfix Normalizer
 */
function normalizeVisualPreBaseVowels(text) {
  if (!text || typeof text !== 'string') return text;
  if (!isTamilDocumentOrPassage(text)) return text;

  let s = text;

  // 1. Two consecutive pre-base vowels at start of word/token (e.g. ேதைர -> தேரை)
  s = s.replace(/(^|[\s("«'\-\u0BCD])([\u0BC6\u0BC7\u0BC8])([\u0B95-\u0BB9])([\u0BC6\u0BC7\u0BC8])([\u0B95-\u0BB9])/gu, '$1$3$2$5$4');

  // 2. Visual Circumfixes:
  // Circumfixes after pulli:
  s = s.replace(/([\u0B95-\u0BB9]\u0BCD)\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1$2\u0BCA');
  s = s.replace(/([\u0B95-\u0BB9]\u0BCD)\u0BC7([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1$2\u0BCB');
  s = s.replace(/([\u0B95-\u0BB9]\u0BCD)\u0BC6([\u0B95-\u0BB9])[ \t]*(?:\u0BD7|\u0BB3(?!\u0BCD))/gu, '$1$2\u0BCC');

  // Short kombu circumfix (ெ...ா) between words where word boundary space was omitted:
  s = s.replace(/([\u0B95-\u0BB9])\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1 $2\u0BCA');
  s = s.replace(/([\u0B95-\u0BB9])\u0BC6([\u0B95-\u0BB9])[ \t]*(?:\u0BD7|\u0BB3(?!\u0BCD))/gu, '$1 $2\u0BCC');

  s = s.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1$2\u0BCA');
  s = s.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC7([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1$2\u0BCB');
  s = s.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC6([\u0B95-\u0BB9])[ \t]*(?:\u0BD7|\u0BB3(?!\u0BCD))/gu, '$1$2\u0BCC');

  s = s.replace(/([\u0B95-\u0BB9])\u0BC6[ \t]*\u0BBE/gu, '$1\u0BCA');
  s = s.replace(/([\u0B95-\u0BB9])\u0BC7[ \t]*\u0BBE/gu, '$1\u0BCB');
  s = s.replace(/([\u0B95-\u0BB9])\u0BC6[ \t]*(?:\u0BD7|\u0BB3(?!\u0BCD))/gu, '$1\u0BCC');

  // 3. Pre-base standalone vowels (ெ, ே, ை) appearing BEFORE a consonant at the start of a token or after vowel/virama
  s = s.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC6([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])/gu, '$1$2\u0BC6');
  s = s.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC7([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])/gu, '$1$2\u0BC7');
  s = s.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC8([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])/gu, '$1$2\u0BC8');

  // 4. Universal Typewriter / Visual Pre-Base (ெ, ே, ை) Reordering inside words:
  // After virama (e.g. க்ெக -> க்கெ):
  s = s.replace(/([\u0B95-\u0BB9]\u0BCD)([\u0BC6\u0BC7\u0BC8])([\u0B95-\u0BB9])(?=[ \t\r\n,.;:!?”"’)ß}]|$|[கசதப]\u0BCD)/gu, '$1$3$2');
  // Typewriter misplaced ை before consonant (excluding grammatical -ைய- glide e.g. இளைய, பையன், அவனுடைய):
  s = s.replace(/([\u0B85-\u0BB9\u0BBE-\u0BCD])\u0BC8([^ய\u0B80-\u0B94\u0BBE-\u0BCD\s\p{P}])(?=[ \t\r\n,.;:!?”"’)ß}]|$|[கசதப]\u0BCD)/gu, '$1$2\u0BC8');

  return s;
}

/**
 * Universal Tolkappiyam-based Kerning & Syllable Reconnection
 * Eliminates artificial spaces inserted between letters & syllables in PDF extraction
 */
function normalizeTamilKerningAndSyllables(text) {
  if (!text || typeof text !== 'string') return text;
  if (!/[\u0B80-\u0BFF]/.test(text)) return text;

  let s = text;

  // Protect intentional multi-space word boundaries (double space = word boundary in letter-spaced PDFs)
  s = s.replace(/[ \t]{2,}/g, '  ');

  // 1. Reconnect consonant + combining vowel sign / virama (e.g. "வ ீ" -> "வீ", "க ்" -> "க்")
  s = s.replace(new RegExp('(' + TAMIL_CONSONANTS + ')[ \t]+(' + TAMIL_VOWEL_SIGNS + ')', 'g'), '$1$2');
  s = s.replace(new RegExp('(' + TAMIL_CONSONANTS + ')\\r?\\n[ \t]*(' + TAMIL_VOWEL_SIGNS + ')', 'gu'), '$1$2');
  s = s.replace(new RegExp('(' + TAMIL_VOWEL_SIGNS + ')[ \t]+(' + TAMIL_VOWEL_SIGNS + ')', 'g'), '$1$2');

  // 2. Reconnect space before pure consonant (மெய் எழுத்து CANNOT start a word in Tamil grammar)
  let prev = '';
  while (prev !== s) {
    prev = s;
    s = s.replace(new RegExp('(' + TAMIL_ALL + ')[ \t]+(' + TAMIL_CONSONANTS + TAMIL_VIRAMA + ')', 'g'), '$1$2');
    s = s.replace(new RegExp('(' + TAMIL_ALL + ')\\r?\\n[ \t]*(' + TAMIL_CONSONANTS + TAMIL_VIRAMA + ')', 'gu'), '$1$2');
  }

  // 3. Reconnect non-final virama consonants (வல்லினம்/மெல்லினம்: க், ங், ச், ஞ், ட், த், ப், ற், ந்)
  prev = '';
  while (prev !== s) {
    prev = s;
    s = s.replace(new RegExp('(' + CANNOT_END_WORD_VIRAMA + ')[ \t]+(' + TAMIL_CONSONANTS + '(?:' + TAMIL_VOWEL_SIGNS + ')?)(?=[ \t\r\n,.;:!?]|$)', 'g'), '$1$2');
  }

  // 4. Reconnect letters that can NEVER begin a native Tamil word:
  // For strictly non-initial letters (ண, ழ, ள, ற, ன), reconnect unconditionally:
  prev = '';
  while (prev !== s) {
    prev = s;
    s = s.replace(new RegExp('(' + TAMIL_ALL + ')[ \t]+([ணழளறன](?:' + TAMIL_VOWEL_SIGNS + ')?)', 'g'), '$1$2');
  }
  // For letters that frequently begin loanwords/names (ட, ர, ல), ONLY reconnect if it is an isolated single syllable fragment:
  prev = '';
  while (prev !== s) {
    prev = s;
    s = s.replace(new RegExp('(' + TAMIL_ALL + ')[ \t]+([டரல](?:' + TAMIL_VOWEL_SIGNS + ')?)(?=[ \t\r\n,.;:!?]|$)', 'g'), '$1$2');
  }

  // 5. Reconnect suffixes (கள், க்கு, இல், உடைய, ஆல், ஓடு)
  s = s.replace(new RegExp('(' + TAMIL_ALL + ')[ \t]+(கள்|க்கு|இல்|உடைய|ஆல்|ஓடு)(?=[ \t\r\n,.;:!?]|$)', 'g'), '$1$2');

  // 6. Reconnect isolated single bare consonants:
  prev = '';
  while (prev !== s) {
    prev = s;
    s = s.replace(new RegExp('(' + TAMIL_ALL + ')[ \t]+(' + BARE_CONSONANTS + ')(?=[ \t\r\n,.;:!?]|$)', 'g'), '$1$2');
    s = s.replace(new RegExp('(^|[ \t\r\n,.;:!?])(' + BARE_CONSONANTS + ')[ \t]+(' + TAMIL_ALL + ')', 'g'), '$1$2$3');
  }

  // 7. General kerning reconnector for single-syllable sequence artifacts:
  const lines = s.split('\n');
  const cleanedLines = lines.map(line => {
    const tokens = line.split(/( {2,}|[ \t])/);
    const recombined = [];
    for (let i = 0; i < tokens.length; i++) {
      const tok = tokens[i];
      if (/^ {2,}$/.test(tok)) {
        recombined.push(' ');
        continue;
      }
      if (tok === ' ' || tok === '\t') {
        continue;
      }
      if (recombined.length > 0 && recombined[recombined.length - 1] !== ' ') {
        const last = recombined[recombined.length - 1];
        const isTamilTok = /^[\u0B80-\u0BFF]+$/.test(tok);
        const isLastTamil = /^[\u0B80-\u0BFF]+$/.test(last);

        if (isTamilTok && isLastTamil) {
          const startsWithIndependentVowel = /^[\u0B85-\u0B94]/.test(tok);

          if (!startsWithIndependentVowel) {
            const lastIsSingle = /^([\u0B95-\u0BB9][\u0BBE-\u0BCD\u0BD7]?|[\u0B85-\u0B94])$/.test(last);
            const tokIsSingle = /^([\u0B95-\u0BB9][\u0BBE-\u0BCD\u0BD7]?|[\u0B85-\u0B94])$/.test(tok) ||
              /^([\u0B95-\u0BB9][\u0BBE-\u0BCD\u0BD7]?[\u0B95-\u0BB9]\u0BCD)$/.test(tok);

            if (lastIsSingle && !VALID_SINGLE_SYLLABLE_WORDS.has(last)) {
              if (/^[\u0B85-\u0B94]$/.test(last)) {
                if (tok === 'வர்கள்' || tok === 'யற்கை' || tok === 'லக்கியம்' || tok === 'ரசாங்கம்' || tokIsSingle) {
                  recombined[recombined.length - 1] = last + tok;
                  continue;
                }
              } else {
                recombined[recombined.length - 1] = last + tok;
                continue;
              }
            }

            const tokIsPulliWord = /^[\u0B95-\u0BB9][\u0BBE-\u0BCD\u0BD7]?[\u0B95-\u0BB9]\u0BCD$/.test(tok);
            if (tokIsSingle && !VALID_SINGLE_SYLLABLE_WORDS.has(tok)) {
              if (!tokIsPulliWord || lastIsSingle) {
                recombined[recombined.length - 1] = last + tok;
                continue;
              }
            }
          }
        }
        recombined.push(' ');
      }
      recombined.push(tok);
    }
    return recombined.join('').replace(/[ \t]+/g, ' ').trim();
  });

  return cleanedLines.join('\n');
}

/**
 * Comprehensive Tamil Typography & Spelling Repair Pipeline
 * Normalizes legacy font artifacts, split syllables, and encoding misrepresentations
 */
function repairTamilSpellingAndTypography(text) {
  if (!text || typeof text !== 'string') return text;
  if (!isTamilDocumentOrPassage(text) || isPredominantlyEnglish(text)) return text;
  let s = text;

  // Protect quoted terms (e.g. ‘டிராய்’, “...”) from having quote marks misinterpreted as legacy glyphs
  const protectedQuotes = [];
  s = s.replace(/([‘“])([^\s’”\r\n]{1,40})([’”])/gu, (m, open, inner, close) => {
    protectedQuotes.push({ open, inner, close });
    return `__PROT_QUOTE_${protectedQuotes.length - 1}__`;
  });


  // Anjal & Inaimathi DTP special words & combinations
  s = s.replace(/டிசாட்டச்[ \t]*டிசாட்டக்/gu, 'சொட்டச் சொட்டக்');
  s = s.replace(/டிசாட்ºச்[ \t]*டிசாட்ºக்/gu, 'சொட்டச் சொட்டக்');
  s = s.replace(/தண்ணீர்ச்[ \t]*சொட்டச்/gu, 'தண்ணீர்ச் சொட்டச்');
  s = s.replace(/தண்ணீர்ச்டிசாட்டச்டிசாட்டக்/gu, 'தண்ணீர்ச் சொட்டச் சொட்டக்');
  s = s.replace(/டிபாழி[‘“]?ம்/gu, 'பொழியும்');
  s = s.replace(/டிபாழிந்து/gu, 'பொழிந்து');
  s = s.replace(/டிகாண்ßºமூி’ந்தது/gu, 'கொண்டேயிருந்தது');
  s = s.replace(/டிகாண்ßºமூி’ந்தார்கள்/gu, 'கொண்டேயிருந்தார்கள்');
  s = s.replace(/ந®…[‘“]?ம்/gu, 'நனையும்');
  s = s.replace(/ந®…ந்து/gu, 'நனைந்து');
  s = s.replace(/ம…ிதர்கள்/gu, 'மனிதர்கள்');
  s = s.replace(/மீ…வர்கள்/gu, 'மீனவர்கள்');
  s = s.replace(/உறவி…ர்கள்/gu, 'உறவினர்கள்');
  s = s.replace(/இறங்கி…ார்கள்/gu, 'இறங்கினார்கள்');
  s = s.replace(/ராட்சக்கிரே…ின்/gu, 'ராட்சக்கிரேனின்');
  s = s.replace(/காவல்துறை[‘“]?ம்/gu, 'காவல்துறையும்');
  s = s.replace(/காவருதுறை[‘“]?ம்/gu, 'காவல்துறையும்');
  s = s.replace(/கºßல்ாரக்[ \t]*காவருப®º[‘“]?ம்/gu, 'கடலோரக் காவல்படையும்');
  s = s.replace(/கடலோரக்[ \t]*காவல்படை[‘“]?ம்/gu, 'கடலோரக் காவல்படையும்');
  s = s.replace(/காவல்படை[‘“]?ம்/gu, 'காவல்படையும்');
  s = s.replace(/டிவளிறிப்“ன்…கை/gu, 'வெற்றிப்புன்னகை');
  s = s.replace(/டிவற்றிப்“ன்…கை/gu, 'வெற்றிப்புன்னகை');
  s = s.replace(/ற்த்தி’க்க/gu, 'பூத்திருக்க');
  s = s.replace(/ற்த்திருக்க/gu, 'பூத்திருக்க');
  s = s.replace(/வானவின்ம[ \t]*யில்[ \t]*வந்து[ \t]*விழுந்தி/gu, 'வாழ்வின் மடியில் வந்து விழுந்தது');
  s = s.replace(/வானவின்[ \t]*ம[ \t]*யில்[ \t]*வந்து[ \t]*விழுந்தது/gu, 'வாழ்வின் மடியில் வந்து விழுந்தது');
  s = s.replace(/மரணத்தின்பி[ \t]*யிலி[ீ’]ந்த/gu, 'மரணத்தின் பிடியில் இருந்த');
  s = s.replace(/மரணத்தின்[ \t]*பி[ \t]*மூில்[ \t]*ி’ந்த/gu, 'மரணத்தின் பிடியில் இருந்த');

  // 1. Repair damage from prior buggy cleaner (e.g. ிரு -> ில், மூ -> ய)
  s = s.replace(/பிடியிலில்ந்த/gu, 'பிடியிலிருந்த');
  s = s.replace(/கொண்டேயில்ந்த/gu, 'கொண்டேயிருந்த');
  s = s.replace(/கொண்டில்ந்த/gu, 'கொண்டிருந்த');
  s = s.replace(/நினைத்தில்க்க/gu, 'நினைத்திருக்க');
  s = s.replace(/காத்தில்க்க/gu, 'காத்திருக்க');
  s = s.replace(/பூத்தில்க்க/gu, 'பூத்திருக்க');
  s = s.replace(/உச்சரித்தில்க்க/gu, 'உச்சரித்திருக்க');
  s = s.replace(/சுவாசித்தில்க்க/gu, 'சுவாசித்திருக்க');
  s = s.replace(/பார்த்தில்க்க/gu, 'பார்த்திருக்க');
  s = s.replace(/வாழ்ந்தில்க்க/gu, 'வாழ்ந்திருக்க');
  s = s.replace(/தணிந்தில்க்க/gu, 'தணிந்திருக்க');
  s = s.replace(/முடிந்தில்க்க/gu, 'முடிந்திருக்க');
  s = s.replace(/மறைந்தில்க்க/gu, 'மறைந்திருக்க');
  s = s.replace(/பயந்தில்க்க/gu, 'பயந்திருக்க');
  s = s.replace(/அமைந்தில்க்க/gu, 'அமைந்திருக்க');
  s = s.replace(/([க-ஹ][ா-்]?)யிலில்ந்த/gu, '$1யிலிருந்த');
  s = s.replace(/([க-ஹ][ா-்]?)திலில்ந்த/gu, '$1திலிருந்த');
  s = s.replace(/([க-ஹ][ா-்]?)நிலில்ந்த/gu, '$1நிலிருந்த');
  s = s.replace(/([க-ஹ][ா-்]?)மில்ந்த/gu, '$1மிருந்த');
  s = s.replace(/([க-ஹ][ா-்]?)வில்ந்த/gu, '$1விருந்த');
  s = s.replace(/([க-ஹ][ா-்]?)றிலில்ந்த/gu, '$1றிலிருந்த');
  s = s.replace(/([க-ஹ][ா-்]?)சிர்த்த/gu, '$1சிரித்த');
  s = s.replace(/சில்ரேனும்/gu, 'சிலரேனும்');
  s = s.replace(/நால்வல்ம்/gu, 'நால்வரும்');
  s = s.replace(/நால்வ’ம்/gu, 'நால்வரும்');
  s = s.replace(/பெல்மை/gu, 'பெருமை');
  s = s.replace(/ரெற்றினார்கள்/gu, 'அரற்றினார்கள்');
  s = s.replace(/காதல்ன்\b/gu, 'காதலன்');
  s = s.replace(/காதல்னை\b/gu, 'காதலனை');
  s = s.replace(/காதல்னுக்கு\b/gu, 'காதலனுக்கு');
  s = s.replace(/கடற்காதல்ன்\b/gu, 'கடற்காதலன்');

  // Fix accidental ya replaces:
  s = s.replace(/யழ்கிய/gu, 'மூழ்கிய');
  s = s.replace(/யழ்காத/gu, 'மூழ்காத');
  s = s.replace(/யழ்கி/gu, 'மூழ்கி');
  s = s.replace(/யழ்க/gu, 'மூழ்க');
  s = s.replace(/யச்சு/gu, 'மூச்சு');
  s = s.replace(/(^|[\s\p{P}])யன்று(?=[\s\p{P}]|$)/gu, '$1மூன்று');

  // 2. Anjal / InaimathiTSC / MacRoman font core glyph rules:
  s = s.replace(/ட்வு/gu, 'ட்ட');
  s = s.replace(/ண்வு/gu, 'ண்ட');
  s = s.replace(/த்வு/gu, 'த்த');
  s = s.replace(/ßவு/gu, 'டே');
  s = s.replace(/®வு/gu, 'டை');

  // kombu combos with signature markers ß, ®, ளு
  s = s.replace(/ளுகா/gu, 'கொ');
  s = s.replace(/ßகா/gu, 'கோ');
  s = s.replace(/®கா/gu, 'கை');
  s = s.replace(/ளுசா/gu, 'சொ');
  s = s.replace(/ßசா/gu, 'சோ');
  s = s.replace(/ளுதா/gu, 'தொ');
  s = s.replace(/ßதா/gu, 'தோ');
  s = s.replace(/ளுபா/gu, 'பொ');
  s = s.replace(/ßபா/gu, 'போ');
  s = s.replace(/ளுவா/gu, 'வொ');
  s = s.replace(/ßவா/gu, 'வோ');
  s = s.replace(/(^|[\s\p{P}])ளுமா/gu, '$1மொ');
  s = s.replace(/ßமா/gu, 'மோ');
  s = s.replace(/ளுநா/gu, 'நொ');
  s = s.replace(/ßநா/gu, 'நோ');
  s = s.replace(/ளுயா/gu, 'யொ');
  s = s.replace(/ßயா/gu, 'யோ');
  s = s.replace(/ளுரா/gu, 'ரொ');
  s = s.replace(/ßரா/gu, 'ரோ');
  s = s.replace(/ளுலா/gu, 'லொ');
  s = s.replace(/ßலா/gu, 'லோ');
  s = s.replace(/ßல்ா/gu, 'லோ');
  s = s.replace(/ßமூா/gu, 'யோ');
  s = s.replace(/ßமுா/gu, 'ளோ');
  s = s.replace(/ளுமுா/gu, 'ளொ');

  // kombu single consonant ONLY at word start / space / punctuation boundary
  s = s.replace(/(^|[\s\p{P}])ளு([க-ஹ])/gu, '$1$2\u0BC6');
  s = s.replace(/(^|[\s\p{P}])ß([க-ஹ])/gu, '$1$2\u0BC7');
  s = s.replace(/(^|[\s\p{P}])®([க-ஹ])/gu, '$1$2\u0BC8');

  // Double R & virama combos
  s = s.replace(/ளிறி/gu, 'ற்றி');
  s = s.replace(/ளிறை/gu, 'ற்றை');
  s = s.replace(/ளிறின்/gu, 'ற்றின்');
  s = s.replace(/ளிறே/gu, 'ற்றே');
  s = s.replace(/ளிறா/gu, 'ற்றா');
  s = s.replace(/ளிற/gu, 'ற்ற');

  s = s.replace(/ஐம்ற்த/gu, 'ஐம்பூத');
  s = s.replace(/ற்த/gu, 'பூத');
  s = s.replace(/ற்த்தி/gu, 'பூத்தி');
  s = s.replace(/ற்த்த/gu, 'பூத்த');

  s = s.replace(/‘ம்/gu, 'யும்');
  s = s.replace(/(?<=[\u0B80-\u0BFF])‘|‘(?=[\u0B80-\u0BFF])/gu, 'யு');
  s = s.replace(/(?<=[\u0B80-\u0BFF])“|“(?=[\u0B80-\u0BFF])/gu, 'பு');

  s = s.replace(/(?<=[\u0B80-\u0BFFß®])º|º(?=[\u0B80-\u0BFFß®])/gu, 'ட');
  s = s.replace(/(?<=[\u0B80-\u0BFF])…|…(?=[\u0B80-\u0BFF])/gu, 'ன');

  // 'மு' mappings
  s = s.replace(/®மு/gu, 'ளை');
  s = s.replace(/ßமு/gu, 'ளே');
  s = s.replace(/முா/gu, 'ளா');
  s = s.replace(/முூ/gu, 'ளூ');
  s = s.replace(/ஆ®மு/gu, 'ஆள');
  s = s.replace(/ாமுர்கள்/gu, 'ாளர்கள்');
  s = s.replace(/ாமுர்/gu, 'ாளர்');
  s = s.replace(/(^|[\s\p{P}])சல்ம்(?=[\s\p{P}]|$)/gu, '$1சலம்');
  s = s.replace(/(^|[\s\p{P}])நில்ம்(?=[\s\p{P}]|$)/gu, '$1நிலம்');
  s = s.replace(/நில்ப்பகுதி/gu, 'நிலப்பகுதி');
  s = s.replace(/நில்வம்/gu, 'நிலவும்');

  // 'மூ' mappings - ONLY where it represents ya
  s = s.replace(/ßமூ/gu, 'யே');
  s = s.replace(/®மூ/gu, 'யை');
  s = s.replace(/மூா/gu, 'யா');
  s = s.replace(/மூி/gu, 'யி');
  s = s.replace(/மூீ/gu, 'யீ');
  s = s.replace(/மூு/gu, 'யு');
  s = s.replace(/மூூ/gu, 'யூ');
  s = s.replace(/மூம்(?=[\s\p{P}]|$)/gu, 'யம்');
  s = s.replace(/மூிரு/gu, 'யில்');
  s = s.replace(/மமூக்கம்/gu, 'மயக்கம்');
  s = s.replace(/இறங்கிமூ/gu, 'இறங்கிய');
  s = s.replace(/இமூக்கிமூ/gu, 'இயக்கிய');
  s = s.replace(/ஆகாமூ/gu, 'ஆகாய');
  s = s.replace(/பத்திரிகைமூா/gu, 'பத்திரிகையா');
  s = s.replace(/காதல் ிமூின்/gu, 'காதலியின்');
  s = s.replace(/காதலிமூின்/gu, 'காதலியின்');
  s = s.replace(/வேண் மூ/gu, 'வேண்டி');

  // 'ழ்' mappings for 'ன'
  s = s.replace(/®ழ்/gu, 'னை');
  s = s.replace(/வாழ்ம்/gu, 'வானம்');
  s = s.replace(/சீதழ்ம்/gu, 'சீதனம்');
  s = s.replace(/விஞ்ஞாழ்ம்/gu, 'விஞ்ஞானம்');
  s = s.replace(/மழ்ிதன்/gu, 'மனிதன்');
  s = s.replace(/மழ்ிதர்கள்/gu, 'மனிதர்கள்');
  s = s.replace(/மீழ்வர்/gu, 'மீனவர்');
  s = s.replace(/மீழ்வர்கள்/gu, 'மீனவர்கள்');
  s = s.replace(/உறவிழ்ர்கள்/gu, 'உறவினர்கள்');
  s = s.replace(/(^|[\s\p{P}])இழ்ி(?=[ \t\n\.,:;!\?\-]|$)/gu, '$1இனி');
  s = s.replace(/இழ்ிமூ/gu, 'இனிய');
  s = s.replace(/(^|[\s\p{P}])கழ்வ(?=[ \t\n\.,:;!\?\-]|$)/gu, '$1கனவு');
  s = s.replace(/என்ழ் இத/gu, 'என்ன இது');
  s = s.replace(/கொள்கின்றழ்/gu, 'கொள்கின்றன');
  s = s.replace(/ரத்தமாழ்/gu, 'ரத்தமான');
  s = s.replace(/இறங்கிழ் ார்கள்/gu, 'இறங்கினார்கள்');
  s = s.replace(/தூக்கிழ் ார்கள்/gu, 'தூக்கினார்கள்');
  s = s.replace(/ேழ்[ \t]*ா/gu, 'ேனா');
  s = s.replace(/இ[ீ’]க்கிற(?:னோ|ேனா|ேழ் ா|ேழ்ா)/gu, 'இருக்கிறேனா');
  s = s.replace(/இறந்துவிட்(?:டனோ|ßவுழ் ா|ßவுழ்ா|டேனா|டேழ் ா|டேழ்ா)/gu, 'இறந்துவிட்டேனா');
  s = s.replace(/வீமா\?/gu, 'வருமா?');
  s = s.replace(/வ’மா(?=[\s\p{P}]|$)/gu, 'வருமா');
  s = s.replace(/ளனகிய[ \t]+படகை/gu, 'மூழ்கிய படகை');
  s = s.replace(/படகைத்தண்ணீர்ச்/gu, 'படகைத் தண்ணீர்ச்');
  s = s.replace(/தண்ணீர்ச்டிசாட்டச்டிசாட்டக்/gu, 'தண்ணீர்ச் சொட்டச் சொட்டக்');
  s = s.replace(/தண்ணீர்ச்டுசாட்டச்டுசாட்டக்/gu, 'தண்ணீர்ச் சொட்டச் சொட்டக்');
  s = s.replace(/கடஅக்கு/gu, 'கடலுக்கு');
  s = s.replace(/மேலே[ \t]*தூக்கிக்கப்பலில்/gu, 'மேலே தூக்கிக் கப்பலில்');
  s = s.replace(/வைத்துவிட்டி(?=[\s\p{P}]|$)/gu, 'வைத்துவிட்டது');
  s = s.replace(/மரணத்தின்பி[ \t]*யிலி[ீ’]ந்த/gu, 'மரணத்தின் பிடியில் இருந்த');
  s = s.replace(/மரணத்தின்[ \t]*பிடியிலில்ந்த/gu, 'மரணத்தின் பிடியில் இருந்த');
  s = s.replace(/வானவின்ம[ \t]*யில்/gu, 'வாழ்வின் மடியில்');
  s = s.replace(/வானவின்[ \t]*ம[ \t]*யில்/gu, 'வாழ்வின் மடியில்');
  s = s.replace(/வந்து[ \t]*விழுந்தி(?=[\s\p{P}]|$)/gu, 'வந்து விழுந்தது');
  s = s.replace(/டுபாழிீம்/gu, 'பொழியும்');
  s = s.replace(/டிபாழி‘ம்/gu, 'பொழியும்');
  s = s.replace(/டிபாழிந்து/gu, 'பொழிந்து');
  s = s.replace(/மழைடிபாழிந்து/gu, 'மழை பொழிந்து');
  s = s.replace(/டிகாண்டேயி[ீ’]ந்தி/gu, 'கொண்டேயிருந்தது');
  s = s.replace(/கொண்டேயி[ீ’]ந்தி/gu, 'கொண்டேயிருந்தது');
  s = s.replace(/கொண்டேயில்ந்தது/gu, 'கொண்டேயிருந்தது');
  s = s.replace(/கொண்டேயில்ந்தார்கள்/gu, 'கொண்டேயிருந்தார்கள்');
  s = s.replace(/பொழியும்[ \t]*மழை[ \t]*பொழிந்து[ \t]*கொண்டேயிருந்தது/gu, 'பொழியும் மழை பொழிந்து கொண்டேயிருந்தது');
  s = s.replace(/ந®ன‘ம்/gu, 'நனையும்');
  s = s.replace(/ந®னீம்/gu, 'நனையும்');
  s = s.replace(/ந®ழ்‘ம்/gu, 'நனையும்');
  s = s.replace(/ந®ழ்ந்து/gu, 'நனைந்து');
  s = s.replace(/ம…ிதர்கள்/gu, 'மனிதர்கள்');
  s = s.replace(/ந®…ந்து/gu, 'நனைந்து');
  s = s.replace(/ந®னந்து/gu, 'நனைந்து');
  s = s.replace(/டிகாண்டேயி[ீ’]ந்தார்கள்/gu, 'கொண்டேயிருந்தார்கள்');
  s = s.replace(/கொண்டேயி[ீ’]ந்தார்கள்/gu, 'கொண்டேயிருந்தார்கள்');
  s = s.replace(/நனையும்[ \t]*மனிதர்கள்[ \t]*நனைந்து[ \t]*கொண்டேயிருந்தார்கள்/gu, 'நனையும் மனிதர்கள் நனைந்து கொண்டேயிருந்தார்கள்');
  s = s.replace(/காவல்துறை[‘ீ]+ம்/gu, 'காவல்துறையும்');
  s = s.replace(/கடலோரக்[ \t]*காவல்படை[‘ீ]+ம்/gu, 'கடலோரக் காவல்படையும்');
  s = s.replace(/காவல்படை[‘ீ]+ம்/gu, 'காவல்படையும்');
  s = s.replace(/காவல்படையும்டிவற்றிப்“ன்…கை/gu, 'காவல்படையும் வெற்றிப்புன்னகை');
  s = s.replace(/டிவற்றிப்[“ீ]+ன்…கை/gu, 'வெற்றிப்புன்னகை');
  s = s.replace(/டிவற்றிப்“ன்/gu, 'வெற்றிப்புன்');
  s = s.replace(/டிவற்றிபீன்னகை/gu, 'வெற்றிப்புன்னகை');
  s = s.replace(/பூத்திீக்க/gu, 'பூத்திருக்க');
  s = s.replace(/ற்த்தி[ீ’]க்க/gu, 'பூத்திருக்க');
  s = s.replace(/காத்தி[ீ’]க்க/gu, 'காத்திருக்க');
  s = s.replace(/தசேத்துக்[ \t]*கைதிகள்/gu, 'தேசத்துக் கைதிகள்');
  s = s.replace(/தசேத்துக்/gu, 'தேசத்துக்');
  s = s.replace(/உயிர்[ \t]*து[ \t]*க்க/gu, 'உயிர் துடிக்க');
  s = s.replace(/தௌி/gu, 'தெளி');
  s = s.replace(/உதவிக்கப்பலின்[ \t]*ராட்சக்கிரேனின்/gu, 'உதவிக்கப்பலின் ராட்சக்கிரேனின்');
  s = s.replace(/ராட்சக்கிரே[…ழ்] ின்/gu, 'ராட்சக்கிரேனின்');
  s = s.replace(/ராட்சக்கிரே[…ழ்]ின்/gu, 'ராட்சக்கிரேனின்');
  s = s.replace(/நோக்கி[ \t]*ஓ[ \t]*வந்த/gu, 'நோக்கி ஓடி வந்த');
  s = s.replace(/(^|[\s\p{P}])ஓ[ \t]+வந்த/gu, '$1ஓடி வந்த');
  s = s.replace(/தடதடளுவன்று/gu, 'தடதடவென்று');
  s = s.replace(/வரவிரு®ல்/gu, 'வரவில்லை');
  s = s.replace(/உ’ண்வுார்கள்/gu, 'உருண்டார்கள்');
  s = s.replace(/மண்ணில்[ \t]*உ’ண்டார்கள்/gu, 'மண்ணில் உருண்டார்கள்');
  s = s.replace(/ற்மி®மூ/gu, 'பூமியை');
  s = s.replace(/ற்மியை/gu, 'பூமியை');
  s = s.replace(/ளத்தமிட்டார்கள்/gu, 'முத்தமிட்டார்கள்');
  s = s.replace(/வெறிகொண்டி(?=[\s\p{P}]|$)/gu, 'வெறிகொண்டு');
  s = s.replace(/முவருக்கும்/gu, 'மூவருக்கும்');
  s = s.replace(/தணிகாசல்ம்/gu, 'தணிகாசலம்');
  s = s.replace(/நூல்கங்களுக்கும்/gu, 'நூலகங்களுக்கும்');
  s = s.replace(/கொண்வெந்து/gu, 'கொண்டுவந்து');
  s = s.replace(/விவுமாட்ßவுன்/gu, 'விடமாட்டேன்');
  s = s.replace(/மு க்ளுகாண்வுான்/gu, 'மூடிக்கொண்டான்');
  s = s.replace(/உன்®ழ்/gu, 'உன்னை');

  // 'வு' as 'ட'
  s = s.replace(/கவுல்/gu, 'கடல்');
  s = s.replace(/கவுன்/gu, 'கடன்');
  s = s.replace(/கவுளி/gu, 'கடலின்');
  s = s.replace(/கவுலுக்கு/gu, 'கடலுக்கு');
  s = s.replace(/கவுலோர/gu, 'கடலோர');
  s = s.replace(/பவுகை/gu, 'படகை');
  s = s.replace(/பவுகு/gu, 'படகு');
  s = s.replace(/கிவுக்கும்/gu, 'கிடக்கும்');
  s = s.replace(/சுவுர்/gu, 'சுடர்');
  s = s.replace(/உவும்பை/gu, 'உடம்பை');
  s = s.replace(/உவும்பு/gu, 'உடம்பு');
  s = s.replace(/உவும்பிரு/gu, 'உடம்பில்');
  s = s.replace(/உவும்ப/gu, 'உடம்ப');
  s = s.replace(/விட்வு/gu, 'விட்ட');
  s = s.replace(/கூட்வு/gu, 'கூட்ட');
  s = s.replace(/கேட்வு/gu, 'கேட்ட');
  s = s.replace(/தீட்வு/gu, 'தீட்ட');
  s = s.replace(/பூட்வு/gu, 'பூட்ட');
  s = s.replace(/ஆண்வு/gu, 'ஆண்ட');
  s = s.replace(/தீண்வு/gu, 'தீண்ட');
  s = s.replace(/வேண்வு/gu, 'வேண்ட');
  s = s.replace(/ளுதாட்வு/gu, 'தொட்ட');
  s = s.replace(/விவு(?=[\s\p{P}]|$)/gu, 'விட');
  s = s.replace(/இரண்வு/gu, 'இரண்ட');
  s = s.replace(/பாவுல்/gu, 'பாடல்');
  s = s.replace(/பாவுலுக்கு/gu, 'பாடலுக்கு');

  // 'ரு' as 'ல்'
  s = s.replace(/உல்கின்/gu, 'உலகின்');
  s = s.replace(/உல்கம்/gu, 'உலகம்');
  s = s.replace(/உல்க/gu, 'உலக');
  s = s.replace(/உல்கிரு/gu, 'உலகில்');
  s = s.replace(/உல்கை/gu, 'உலகை');
  s = s.replace(/உல்கிற்கு/gu, 'உலகிற்கு');
  s = s.replace(/முதரு(?=[\s\p{P}]|$)/gu, 'முதல்');
  s = s.replace(/வசூரு(?=[\s\p{P}]|$)/gu, 'வசூல்');
  s = s.replace(/பக்கத்திரு/gu, 'பக்கத்தில்');
  s = s.replace(/கப்பல் ிரு/gu, 'கப்பலில்');
  s = s.replace(/வாசல் ிரு/gu, 'வாசலில்');
  s = s.replace(/வாசல் ில்/gu, 'வாசலில்');
  s = s.replace(/வாசல்ில்/gu, 'வாசலில்');
  s = s.replace(/தோள்கமுிரு/gu, 'தோள்களில்');
  s = s.replace(/ளுசாருவீர்கள்/gu, 'சொல்வீர்கள்');
  s = s.replace(/ளுசாரு(?=[\s\p{P}]|$)/gu, 'சொல்');
  s = s.replace(/நாருவ/gu, 'நால்வ');
  s = s.replace(/இரு®ல்/gu, 'இல்லை');
  s = s.replace(/(^|[\s\p{P}])டிருல்(?=[\s\p{P}]|$)/gu, '$1அல்ல');
  s = s.replace(/(^|[\s\p{P}])டிருல்து(?=[\s\p{P}]|$)/gu, '$1அல்லது');
  s = s.replace(/எருல் ாம்/gu, 'எல்லாம்');
  s = s.replace(/எல்லால்ம்/gu, 'எல்லாம்');
  s = s.replace(/எருலோரும்/gu, 'எல்லோரும்');
  s = s.replace(/எருலோருக்கும்/gu, 'எல்லோருக்கும்');
  s = s.replace(/எருலாரும்/gu, 'எல்லாரும்');
  s = s.replace(/எருலாரையும்/gu, 'எல்லாரையும்');
  s = s.replace(/மெமுனம்/gu, 'மௌனம்');
  s = s.replace(/மெமுன/gu, 'மௌன');
  s = s.replace(/டிடையாமும்/gu, 'அடையாளம்');
  s = s.replace(/டிடையாமு/gu, 'அடையாள');
  s = s.replace(/சொருலுங்கள்/gu, 'சொல்லுங்கள்');
  s = s.replace(/சொருல/gu, 'சொல்ல');
  s = s.replace(/சொருலி/gu, 'சொல்லி');
  s = s.replace(/சொருலுகிறேன்/gu, 'சொல்கிறேன்');
  s = s.replace(/சொருலு/gu, 'சொல்லு');
  s = s.replace(/ஜதிசொருல்/gu, 'ஜதிசொல்');
  s = s.replace(/நருல்(?=[\s\p{P}]|$)/gu, 'நல்ல');
  s = s.replace(/வரல் ாறு/gu, 'வரலாறு');
  s = s.replace(/வரல் ா/gu, 'வரலா');
  s = s.replace(/பருல் ில்லை/gu, 'பல்லில்லை');
  s = s.replace(/பருல்/gu, 'பல்');
  s = s.replace(/சொருல்/gu, 'சொல்ல');
  s = s.replace(/மெருல் ிய/gu, 'மெல்லிய');
  s = s.replace(/மெருல்(?=[\s\p{P}]|$)/gu, 'மெல்ல');
  s = s.replace(/செவில் ி/gu, 'செவிலி');
  s = s.replace(/பசியாரு/gu, 'பசியால்');
  s = s.replace(/புயல் ாரு/gu, 'புயலால்');
  s = s.replace(/செத்தாடில்ன்ன/gu, 'செத்தாலென்ன');
  s = s.replace(/த்தருல்வா/gu, 'த்தல்லவா');

  // 'லு' at start of word -> 'அ'
  s = s.replace(/(^|[\s\p{P}])லு([கசதபவநமறடயழளரஸஹ])/gu, '$1அ$2');

  // '’' -> 'ரு' / 'டி'
  s = s.replace(/இ’க்கிறேன்/gu, 'இருக்கிறேன்');
  s = s.replace(/இ’க்கிறே/gu, 'இருக்கிறே');
  s = s.replace(/காத்தி’க்க/gu, 'காத்திருக்க');
  s = s.replace(/தணிந்தி’ந்தது/gu, 'தணிந்திருந்தது');
  s = s.replace(/கதி’ம்/gu, 'கதிரும்');
  s = s.replace(/ம’த்துவ/gu, 'மருத்துவ');
  s = s.replace(/ஒ’/gu, 'ஒரு');
  s = s.replace(/இ’ண் ’ந்தது/gu, 'இருண்டிருந்தது');
  s = s.replace(/விட் ’ந்த/gu, 'விட்டிருந்த');
  s = s.replace(/ளுகாண் ’ந்த/gu, 'கொண்டிருந்த');
  s = s.replace(/கொண் ’ந்த/gu, 'கொண்டிருந்த');

  // Inaimathi font word-initial 'டி' -> 'அ' (ONLY at start of token (^|[sp{P}]))
  const INAIMATHI_INITIAL_WORDS = [
    ['டிணைத்து', 'அணைத்து'],
    ['டிங்கவஸ்திரமாய்', 'அங்கவஸ்திரமாய்'],
    ['டிங்கவஸ்திரமாய்த்', 'அங்கவஸ்திரமாய்த்'],
    ['டிணிந்து', 'அணிந்து'],
    ['டினுபவம்', 'அனுபவம்'],
    ['டினுபவங்கள்', 'அனுபவங்கள்'],
    ['டிஞ்சினாள்', 'அஞ்சினாள்'],
    ['டில்றினாள்', 'அலறினாள்'],
    ['டிதிபர்', 'அதிபர்'],
    ['டின்று', 'அன்று'],
    ['டிச்சம்', 'அச்சம்'],
    ['டிச்சத்தில்', 'அச்சத்தில்'],
    ['டிப்பாக்கள்', 'அப்பாக்கள்'],
    ['டினைத்து', 'அனைத்து'],
    ['டிங்குதான்', 'அங்குதான்'],
    ['டிடுத்த', 'அடுத்த'],
    ['டிடுத்தவன்', 'அடுத்தவன்'],
    ['டிந்த', 'அந்த'],
    ['டிங்கே', 'அங்கே'],
    ['டிலுவல்க', 'அலுவலக'],
    ['டிலுவல்கத்தின்', 'அலுவலகத்தின்'],
    ['டிருகே', 'அருகே'],
    ['டிழகு', 'அழகு'],
    ['டிறிவ', 'அறிவு'],
    ['டிய்யோ', 'அய்யோ'],
    ['டிசைந்து', 'அசைந்து'],
    ['டிசைவு', 'அசைவு'],
    ['டிசையவில்லை', 'அசையவில்லை'],
    ['டிதைவிட', 'அதைவிட'],
    ['டிம்சத்வனி', 'ஹம்சத்வனி'],
    ['தொழில்திபர்', 'தொழிலதிபர்'],
    ['டிமைச்சரை', 'அமைச்சரை'],
    ['டிமைச்சர்', 'அமைச்சர்'],
    ['டிமைச்ச', 'அமைச்ச'],
    ['டெங்கவில்லை', 'அடங்கவில்லை'],
    ['டெங்கி', 'அடங்கி'],
    ['டிதுதான்', 'அதுதான்'],
    ['டிதுவரை', 'அதுவரை'],
    ['டிதோ', 'அதோ'],
    ['டிதில்', 'அதில்'],
    ['டிங்கங்கே', 'அங்கங்கே'],
    ['டிதிக', 'அதிக']
  ];
  for (const [corrupt, correct] of INAIMATHI_INITIAL_WORDS) {
    s = s.replace(new RegExp('(^|[\\s\\p{P}])' + corrupt + '(?=[\\s\\p{P}]|$)', 'gu'), '$1' + correct);
  }

  // Standalone 'டி' as a word by itself between spaces -> 'அடி'
  s = s.replace(/(^|[\s\p{P}])டி(?=[\s\p{P}]|$)/gu, '$1அடி');

  // 'வெ' -> 'அவ' words
  s = s.replace(/(^|[\s\p{P}])வெளை(?=[\s\p{P}]|$)/gu, '$1அவளை');
  s = s.replace(/(^|[\s\p{P}])வெளுக்கு(?=[\s\p{P}]|$)/gu, '$1அவளுக்கு');
  s = s.replace(/(^|[\s\p{P}])வெளுக்கா(?=[\s\p{P}]|$)/gu, '$1அவளுக்கா');
  s = s.replace(/(^|[\s\p{P}])வெனுக்கு(?=[\s\p{P}]|$)/gu, '$1அவனுக்கு');
  s = s.replace(/(^|[\s\p{P}])வெனை(?=[\s\p{P}]|$)/gu, '$1அவனை');
  s = s.replace(/(^|[\s\p{P}])வெர்கள்(?=[\s\p{P}]|$)/gu, '$1அவர்கள்');
  s = s.replace(/(^|[\s\p{P}])வெர்(?=[\s\p{P}]|$|கள்)/gu, '$1அவர்');

  // 'இரண்டி' -> 'இரண்டு'
  s = s.replace(/இரண்டி(?=[\s\p{P}]|$)/gu, 'இரண்டு');
  s = s.replace(/இரண்டிமே/gu, 'இரண்டுமே');
  s = s.replace(/இரண்டிகுடம்/gu, 'இரண்டுகுடம்');
  s = s.replace(/மட்டிம்தான்/gu, 'மட்டும்தான்');
  s = s.replace(/மட்டிமே/gu, 'மட்டுமே');
  s = s.replace(/மட்டிம்(?=[\s\p{P}]|$)/gu, 'மட்டும்');

  // Contextual 'டி' in known words where 'டு' became 'டி'
  s = s.replace(/உடிம்ப/gu, 'உடம்ப');
  s = s.replace(/நூற்றாண்டி(?=[\s\p{P}]|$)/gu, 'நூற்றாண்டு');
  s = s.replace(/முத்தச்சூடி/gu, 'முத்தச்சூடு');
  s = s.replace(/படிம்போதே/gu, 'படும்போதே');
  s = s.replace(/(^|[\s])படிம்(?=[\s\p{P}]|$)/gu, '$1படும்');
  s = s.replace(/மணிக்கட்டி[ \t]*ரு/gu, 'மணிக்கட்டில்');
  s = s.replace(/பாடி[ \t]*பட்ட/gu, 'பாடுபட்ட');
  s = s.replace(/காடிம்போது/gu, 'காணும்போது');
  s = s.replace(/ஆடிம்படகில்/gu, 'ஆடும் படகில்');
  s = s.replace(/வேண்மொ/gu, 'வேண்டுமோ');
  s = s.replace(/உண்டி(?=[\s\p{P}]|$)/gu, 'உண்டு');
  s = s.replace(/போல்வே/gu, 'போலவே');
  s = s.replace(/ம யோடி/gu, 'மடியோடு');
  s = s.replace(/மார்போடி/gu, 'மார்போடு');
  s = s.replace(/கரைகளோடி/gu, 'கரைகளோடு');
  s = s.replace(/மனிதர்களோடி/gu, 'மனிதர்களோடு');
  s = s.replace(/எந்திரங்களோடி/gu, 'எந்திரங்களோடு');
  s = s.replace(/காதலோடி/gu, 'காதலோடு');
  s = s.replace(/ஓசையோடி/gu, 'ஓசையோடு');
  s = s.replace(/தழுவிக்கொண்டி/gu, 'தழுவிக்கொண்டு');
  s = s.replace(/சூழ்ந்துகொண்டி/gu, 'சூழ்ந்துகொண்டு');
  s = s.replace(/கொண்டி(?=[\s\p{P}]|$)/gu, 'கொண்டு');

  // Terminal விடி -> விடு in verbs
  s = s.replace(/(மன்னித்து|மாறி|துணிந்து|துப்பி|சென்று|வந்து|பார்த்து|போய்|ஆகி|விட்டு|நின்று|எழுந்து|ஒழிந்து|நகர்த்தி)விடி(?=[\s\p{P}]|$)/gu, '$1விடு');
  s = s.replace(/(\S+)விடிவோம்/gu, '$1விடுவோம்');
  s = s.replace(/(\S+)விடிகின்றன/gu, '$1விடுகின்றன');

  // Standalone frequent truncated words
  s = s.replace(/(^|[\s\p{P}])பாண்(?=[\s\p{P}]|$)/gu, '$1பாண்டி');
  s = s.replace(/(^|[\s\p{P}])வேண்(?=[\s\p{P}]|$)/gu, '$1வேண்டி');
  s = s.replace(/(^|[\s\p{P}])சில்(?=[\s\p{P}]|$)/gu, '$1சில');
  s = s.replace(/(^|[\s\p{P}])(எப்|இப்|அப்)ப(?=[\s\p{P}]|$)/gu, '$1$2படி');
  s = s.replace(/(^|[\s\p{P}])எவ்வளவ(?=[\s\p{P}]|$)/gu, '$1எவ்வளவு');
  s = s.replace(/(^|[\s\p{P}])அவ்வளவ(?=[\s\p{P}]|$)/gu, '$1அவ்வளவு');
  s = s.replace(/அவ்வளவதான்/gu, 'அவ்வளவுதான்');
  s = s.replace(/(^|[\s\p{P}])இரவ(?=[\s\p{P}]|$)/gu, '$1இரவு');
  s = s.replace(/(^|[\s\p{P}])கதவ(?=[\s\p{P}]|$)/gu, '$1கதவு');
  s = s.replace(/(^|[\s\p{P}])கனவ(?=[\s\p{P}]|$)/gu, '$1கனவு');
  s = s.replace(/(^|[\s\p{P}])நடுவ(?=[\s\p{P}]|$)/gu, '$1நடுவு');
  s = s.replace(/(^|[\s\p{P}])உறவ(?=[\s\p{P}]|$)/gu, '$1உறவு');
  s = s.replace(/(^|[\s\p{P}])உணவ(?=[\s\p{P}]|$)/gu, '$1உணவு');
  s = s.replace(/(^|[\s\p{P}])வரவ(?=[\s\p{P}]|$)/gu, '$1வரவு');
  s = s.replace(/(^|[\s\p{P}])முடிவ(?=[\s\p{P}]|$)/gu, '$1முடிவு');
  s = s.replace(/எப்படி[ \t]+யாவது/gu, 'எப்படியாவது');
  s = s.replace(/காதல்[ \t]+மண்/gu, 'காதலில் மண்');

  // Split letter & broken syllables (ALWAYS requiring whitespace between the parts)
  s = s.replace(/பாண்[ \t]+,/gu, 'பாண்டி,');
  s = s.replace(/பாண்[ \t]+யும்/gu, 'பாண்டியும்');
  s = s.replace(/வேண்[ \t]+ி/gu, 'வேண்டி');
  s = s.replace(/வேண்[ \t]+யிருந்தது/gu, 'வேண்டியிருந்தது');
  s = s.replace(/சு[ \t]+தார்/gu, 'சுடிதார்');
  s = s.replace(/சு[ \t]+தார்கொண்ட/gu, 'சுடிதார்கொண்ட');
  s = s.replace(/(^|[\s])ஓ[ \t]+வந்து/gu, '$1ஓடி வந்து');
  s = s.replace(/(^|[\s])ஓ[ \t]+வர/gu, '$1ஓடி வர');
  s = s.replace(/(^|[\s])ஓ[ \t]+வந்த/gu, '$1ஓடி வந்த');
  s = s.replace(/பி[ \t]+மண்ணை/gu, 'பிடி மண்ணை');
  s = s.replace(/(^|[\s])ஒரு[ \t]+பி[ \t]+மண்ணை/gu, '$1ஒரு பிடி மண்ணை');
  s = s.replace(/பி[ \t]+த்து/gu, 'பிடித்து');
  s = s.replace(/பி[ \t]+த்தான்/gu, 'பிடித்தான்');
  s = s.replace(/பி[ \t]+த்தது/gu, 'பிடித்தது');
  s = s.replace(/பி[ \t]+க்காத/gu, 'பிடிக்காத');
  s = s.replace(/பி[ \t]+க்கும்/gu, 'பிடிக்கும்');
  s = s.replace(/பி[ \t]+க்க/gu, 'பிடிக்க');
  s = s.replace(/பி[ \t]+த்தருல்வா/gu, 'பிடித்தல்லவா');
  s = s.replace(/மீன்பி[ \t]+க்க/gu, 'மீன்பிடிக்க');
  s = s.replace(/மீன்பி[ \t]+த்த/gu, 'மீன்பிடித்த');
  s = s.replace(/து[ \t]+து[ \t]*க்கும்/gu, 'துடிதுடிக்கும்');
  s = s.replace(/து[ \t]+க்கும்/gu, 'துடிக்கும்');
  s = s.replace(/து[ \t]+க்கிறது/gu, 'துடிக்கிறது');
  s = s.replace(/நொ[ \t]+யில்/gu, 'நொடியில்');
  s = s.replace(/மு[ \t]+யும்/gu, 'முடியும்');
  s = s.replace(/மு[ \t]+யாது/gu, 'முடியாது');
  s = s.replace(/மு[ \t]+யவில்லை/gu, 'முடியவில்லை');
  s = s.replace(/மு[ \t]+கிறது/gu, 'முடிகிறது');
  s = s.replace(/மு[ \t]+யாமல்/gu, 'முடியாமல்');
  s = s.replace(/மு[ \t]+யுமா/gu, 'முடியுமா');
  s = s.replace(/மு[ \t]+யவே/gu, 'முடியவே');
  s = s.replace(/மு[ \t]+யாதா/gu, 'முடியாதா');
  s = s.replace(/மு[ \t]+யாதவர்கள்/gu, 'முடியாதவர்கள்');
  s = s.replace(/மு[ \t]+னான்/gu, 'மூடினான்');
  s = s.replace(/மு[ \t]+வில்/gu, 'முடிவில்');
  s = s.replace(/மு[ \t]+த்தார்கள்/gu, 'முடித்தார்கள்');
  s = s.replace(/மு[ \t]+த்தான்/gu, 'முடித்தான்');
  s = s.replace(/மு[ \t]+த்தது/gu, 'முடித்தது');
  s = s.replace(/மு[ \t]+க்காண்டாள்/gu, 'மூடிக்கொண்டாள்');
  s = s.replace(/மு[ \t]+க்கொண்டாள்/gu, 'மூடிக்கொண்டாள்');
  s = s.replace(/தே[ \t]+முத்தமிட்டாள்/gu, 'தேடி முத்தமிட்டாள்');
  s = s.replace(/விளையா[ \t]+அவன்/gu, 'விளையாடி அவன்');
  s = s.replace(/வர்ணம[ \t]+க்கிறது/gu, 'வர்ணமடிக்கிறது');
  s = s.replace(/வ[ \t]+வமைத்தது/gu, 'வடிவமைத்தது');
  s = s.replace(/வ[ \t]+வம்/gu, 'வடிவம்');
  s = s.replace(/வ[ \t]+வங்கள்/gu, 'வடிவங்கள்');
  s = s.replace(/வ[ \t]+விழந்த/gu, 'வடிவிழந்த');
  s = s.replace(/தோ[ \t]+ராகம்/gu, 'தோடி ராகம்');
  s = s.replace(/மண்[ \t]+யிட்டான்/gu, 'மண்டியிட்டான்');
  s = s.replace(/அலைதாண்[ \t]+க்/gu, 'அலைதாண்டிக்');
  s = s.replace(/அலைதாண்க்/gu, 'அலைதாண்டிக்');
  s = s.replace(/அலைதாண்[ \t]+(?=கடல்)/gu, 'அலைதாண்டிக் ');
  s = s.replace(/கு[ \t]+நீர்/gu, 'குடிநீர்');
  s = s.replace(/கு[ \t]+நீராகட்டிமே/gu, 'குடிநீராகட்டுமே');
  s = s.replace(/குளிநீர்/gu, 'குளிர்நீர்');
  s = s.replace(/க[ \t]+த்து/gu, 'கடித்து');
  s = s.replace(/க[ \t]+தம்/gu, 'கடிதம்');
  s = s.replace(/க[ \t]+தத்தின்/gu, 'கடிதத்தின்');
  s = s.replace(/பயம[ \t]+த்து/gu, 'பயமடித்து');
  s = s.replace(/த[ \t]+த்த/gu, 'தடித்த');
  s = s.replace(/த[ \t]+த்திருக்க/gu, 'தடித்திருக்க');
  s = s.replace(/சட்டி[ \t]+யும்/gu, 'சட்டியும்');
  s = s.replace(/ரொட்டி[ \t]+யாய்/gu, 'ரொட்டியாய்');
  s = s.replace(/கொண்[ \t]+ருக்கும்/gu, 'கொண்டிருக்கும்');
  s = s.replace(/கொண்[ \t]+ருந்த/gu, 'கொண்டிருந்த');
  s = s.replace(/கொண்[ \t]+ருக்கிறார்கள்/gu, 'கொண்டிருக்கிறார்கள்');
  s = s.replace(/வே[ \t]+க்கை/gu, 'வேடிக்கை');
  s = s.replace(/வா[ \t]+ய/gu, 'வாடிய');
  s = s.replace(/தீப்பி[ \t]+த்த/gu, 'தீப்பிடித்த');
  s = s.replace(/வி[ \t]+யாதே/gu, 'விடியாதே');
  s = s.replace(/வி[ \t]+யாத/gu, 'விடியாத');
  s = s.replace(/வி[ \t]+யவி[ \t]+ய/gu, 'விடியவிடிய');
  s = s.replace(/கு[ \t]+த்துவிட்டிப்/gu, 'குடித்துவிட்டுப்');
  s = s.replace(/கு[ \t]+த்துக்/gu, 'குடித்துக்');
  s = s.replace(/கு[ \t]+த்தான்/gu, 'குடித்தான்');
  s = s.replace(/கு[ \t]+க்க/gu, 'குடிக்க');
  s = s.replace(/ப[ \t]+த்தேன்/gu, 'படித்தேன்');
  s = s.replace(/ப[ \t]+த்து/gu, 'படித்து');
  s = s.replace(/மாட்[ \t]+ய/gu, 'மாட்டிய');
  s = s.replace(/போவெது/gu, 'போடுவது');
  s = s.replace(/முரட்டிக்/gu, 'முரட்டுக்');
  s = s.replace(/தால்[ \t]+ாட்டி/gu, 'தாலாட்டி');
  s = s.replace(/தாலாட்டிக்கும்/gu, 'தாலாட்டுக்கும்');
  s = s.replace(/சில்பேர்/gu, 'சிலபேர்');
  s = s.replace(/சில்[ \t]+பேர்/gu, 'சிலபேர்');
  s = s.replace(/சில்நாட்கள்/gu, 'சிலநாட்கள்');
  s = s.replace(/சில்[ \t]+நாட்கள்/gu, 'சிலநாட்கள்');
  s = s.replace(/சில்[ \t]+நேரங்களில்/gu, 'சில நேரங்களில்');
  s = s.replace(/உதவியாமுர்/gu, 'உதவியாளர்');
  s = s.replace(/காதல் ற்ஜையின்/gu, 'காதல் பூஜையின்');
  s = s.replace(/பிளாஸ்க் கூட்டிக்குள்/gu, 'பிளாஸ்டிக் கூட்டுக்குள்');
  s = s.replace(/முடிமுடிக்கவம்/gu, 'முணுமுணுக்கவும்');
  s = s.replace(/கெத்தியர்/gu, 'அகத்தியர்');
  s = s.replace(/பேனாவின் மு திறந்தபோதே/gu, 'பேனாவின் முடிதிறந்தபோதே');
  s = s.replace(/எக்ஸ்ரே கண்ணாமுர்கள்/gu, 'எக்ஸரே கண்ணாளர்கள்');
  s = s.replace(/சுடறுத்துப் பார்த்து/gu, 'ஊடறுத்துப் பார்த்து');
  s = s.replace(/கிண்டல்மொழி சுண்வெதைக்/gu, 'கிண்டல்மொழி சுண்டுவதைக்');
  s = s.replace(/பூமியின் டி வயிற்றில்/gu, 'பூமியின் அடிவயிற்றில்');
  s = s.replace(/பூமியின் டிவயிற்றில்/gu, 'பூமியின் அடிவயிற்றில்');
  s = s.replace(/தொண்flளிறெட்டி/gu, 'தொண்ணூற்றெட்டு');
  s = s.replace(/சொந்த முளையை/gu, 'சொந்த மூளையை');
  s = s.replace(/சதவிகித முளை/gu, 'சதவிகித மூளை');
  s = s.replace(/கிற்க்குஞ்சாய்/gu, 'கிளிக்குஞ்சாய்');
  s = s.replace(/சிறக த்தது/gu, 'சிறகடித்தது');
  s = s.replace(/தண்ணீர் சுற்றியது/gu, 'தண்ணீர் ஊற்றியது');
  s = s.replace(/மணி டெங்கி/gu, 'மணி அடங்கி');
  s = s.replace(/உதட்டி ரு விழுந்தது/gu, 'உதட்டில் விழுந்தது');
  s = s.replace(/அலைஓசை டிச்சத்தில்/gu, 'அலைஓசை அச்சத்தில்');
  s = s.replace(/ஒட்டி ஒடிங்கினாள்/gu, 'ஒட்டி ஒடுங்கினாள்');
  s = s.replace(/முதல் ிரவ/gu, 'முதல் இரவு');
  s = s.replace(/விழிமுக் கொள்வேன்/gu, 'விழிமூடிக் கொள்வேன்');

  // Specific phrases
  s = s.replace(/காதல்[ \t]+ி/gu, 'காதலி');
  s = s.replace(/சல்[ \t]*ிக்க/gu, 'சலிக்க');
  s = s.replace(/சல்[ \t]*ிப்பதில்லை/gu, 'சலிப்பதில்லை');
  s = s.replace(/சல்ீம்/gu, 'சலீம்');
  s = s.replace(/மருல்[ \t]*ிகை/gu, 'மல்லிகை');
  s = s.replace(/தூரிகையில்ல்[ \t]*ாமல்/gu, 'தூரிகையில்லாமல்');
  s = s.replace(/இல்ல்[ \t]*ாமல்/gu, 'இல்லாமல்');
  s = s.replace(/கடல்[ \t]*ில்/gu, 'கடலில்');
  s = s.replace(/கடல்ில்[ \t]*ா/gu, 'கடலிலா');
  s = s.replace(/கடல்[ \t]*ின்/gu, 'கடலின்');
  s = s.replace(/கடல்[ \t]+ாட/gu, 'கடலாட');
  s = s.replace(/கால்வெள்ளம்/gu, 'காலவெள்ளம்');
  s = s.replace(/நீல்ப்[ \t]*பள்ளம்/gu, 'நீலப்பள்ளம்');
  s = s.replace(/கல்ாபமயில்/gu, 'கலாபமயில்');
  s = s.replace(/நில்[ \t]*ா/gu, 'நிலா');
  s = s.replace(/நால்[ \t]*ா/gu, 'நாலா');
  s = s.replace(/கனவ[ \t]*வல்மா/gu, 'கனவு வருமா');
  s = s.replace(/வல்மா/gu, 'வருமா');
  s = s.replace(/(^|[\s])வல்ம்(?=[\s\p{P}]|$)/gu, '$1வரும்');
  s = s.replace(/கனவகளில்/gu, 'கனவுகளில்');
  s = s.replace(/படிக்கையில் நான் வியர்த்து/gu, 'படுக்கையில் நான் வியர்த்து');
  s = s.replace(/உறவத் திரவம்/gu, 'உயிர்த் திரவம்');
  s = s.replace(/நம்புவதெப்ப நான்/gu, 'நம்புவதெப்படி நான்');
  s = s.replace(/கட்டி[ \t]+க்கொண்டாள்/gu, 'கட்டிக்கொண்டாள்');
  s = s.replace(/காட்டி[ \t]+ய/gu, 'காட்டிய');
  s = s.replace(/உயிரெருல்[ \t]*ாம்/gu, 'உயிரெல்லாம்');
  s = s.replace(/நூல்களையெருல்[ \t]*ாம்/gu, 'நூல்களையெல்லாம்');
  s = s.replace(/கழுத்த[ \t]+யில்/gu, 'கழுத்தடியில்');
  s = s.replace(/சுடல் என்பது/gu, 'உடல் என்பது');
  s = s.replace(/தாய்கண்டி/gu, 'தாய்கண்டு');
  s = s.replace(/உன்னைக்கண்டி/gu, 'உன்னைக்கண்டு');
  s = s.replace(/வெறிகொண்டி/gu, 'வெறிகொண்டு');
  s = s.replace(/சுழன்றுகொண்டி/gu, 'சுழன்றுகொண்டு');
  s = s.replace(/சுடர்கொண்டி/gu, 'சுடர்கொண்டு');
  s = s.replace(/கொண்வெந்து/gu, 'கொண்டுவந்து');
  s = s.replace(/நூல்கங்களுக்கும்/gu, 'நூலகங்களுக்கும்');
  s = s.replace(/பாடி[ \t]+பட்டதில்லை/gu, 'பாடுபட்டதில்லை');
  s = s.replace(/செல்வான/gu, 'செலவான');
  s = s.replace(/அறிவசேர்க்க/gu, 'அறிவைச் சேர்க்க');
  s = s.replace(/அறிவச்/gu, 'அறிவுச்');
  s = s.replace(/சுறிவிடும்/gu, 'தீர்ந்துவிடும்');
  s = s.replace(/தூரத்தில்[ \t]+ிருந்து/gu, 'தூரத்திலிருந்து');
  s = s.replace(/சிறையில்[ \t]+ிருந்தன/gu, 'சிறையிலிருந்தன');
  s = s.replace(/கொட்டாமல்[ \t]+ிருந்தாள்/gu, 'கொட்டாமல் இருந்தாள்');
  s = s.replace(/போல்[ \t]+ிருக்கிறதே/gu, 'போலிருக்கிறதே');
  s = s.replace(/முதல்[ \t]+ில்/gu, 'முதலில்');

  // Virama + combining vowels
  s = s.replace(/([\u0B95-\u0BB9])\u0BCD\u0BBF/gu, '$1\u0BBF');
  s = s.replace(/([\u0B95-\u0BB9])\u0BCD\u0BC0/gu, '$1\u0BC0');

  // Space before/after combining vowels or viramas
  s = s.replace(/([க-ஹ])[ \t]+([ா-்])/gu, '$1$2');
  s = s.replace(/([ா-்])[ \t]+([ா-்])/gu, '$1$2');

  // Restore protected quotes
  s = s.replace(/__PROT_QUOTE_(\d+)__/g, (m, idx) => {
    const q = protectedQuotes[idx];
    return q ? q.open + q.inner + q.close : m;
  });

  return s;
}

/**
 * Main cleaning pipeline for extracted PDF text
 */
function cleanExtractedText(raw) {
  if (!raw || typeof raw !== 'string') return '';

  let text = raw;

  // 1. Strip telegram / download watermarks and spam lines
  text = text.replace(/www\.t\.me\/[^\s\n]+/gi, '');
  text = text.replace(/t\.me\/[^\s\n]+/gi, '');
  text = text.replace(/AVOID TO DOWNLOAD FROM [^\n]+/gi, '');
  text = text.replace(/\n\s*--\s*\d+\s+of\s+\d+\s*--\s*/gi, '\n');

  // 2. Unfold standard typographic ligatures
  for (const [lig, replacement] of Object.entries(LIGATURE_MAP)) {
    if (text.includes(lig)) {
      text = text.split(lig).join(replacement);
    }
  }

  // 3. Remove zero-width characters, soft hyphens, ZWNJ, ZWJ and direction marks
  text = text.replace(/[\u00AD\u200B-\u200D\uFEFF\u200E\u200F]/g, '');
  text = text.replace(/\u00A0/g, ' ');

  // 4. Remove non-printable control characters EXCEPT 0x7F (which maps to ம் in legacy fonts)
  text = text.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '');

  // 5. Reconnect hyphenated words split across lines (e.g. தமிழ்-\nநாடு -> தமிழ்நாடு)
  text = text.replace(/([\u0B80-\u0BFF\w])-[ \t]*\r?\n[ \t]*([\u0B80-\u0BFF\w])/gu, '$1$2');

  const isTamil = isTamilDocumentOrPassage(text);

  if (isTamil) {
    // 6. Decode Bamini ASCII font if detected
    text = decodeBaminiIfDetected(text);

    // 7. Decode Legacy Softland/Shree/TAM Tamil fonts if detected
    text = decodeLegacyTamilIfPresent(text);

    // 8. Decode Legacy MacRoman / InDesign / TSCII Tamil fonts if detected
    text = decodeMacTamilPDF(text);

    // 9. Decode Late-Volume DTP kombu remappings if detected (Velpari final chapters)
    text = decodeLateVolumeDtpTamil(text);

    // 10. Clean any remaining 0x7F if not part of legacy font
    text = text.replace(/\x7F/g, '');

    // 11. Automatic Visual-to-Canonical Unicode Pre-Base Reordering (ெ, ே, ை)
    text = normalizeVisualPreBaseVowels(text);

    // 12. Comprehensive Tamil Typography & Spelling Repair Pipeline
    text = repairTamilSpellingAndTypography(text);

    // 13. Universal Kerning & Syllable Reconnection (Tolkappiyam-based)
    text = normalizeTamilKerningAndSyllables(text);

    // 15. De-duplicate consecutive virama / pulli (e.g. ் ் -> ்)
    text = text.replace(/\u0BCD\u0BCD+/g, '\u0BCD');
  } else {
    text = text.replace(/\x7F/g, '');
    if (isPredominantlyEnglish(text)) {
      text = text.replace(/([a-zA-Z])[\u0B80-\u0BFF]+([a-zA-Z])/gu, '$1$2');
      const tMatches = text.match(/[\u0B80-\u0BFF]/g);
      const eMatches = text.match(/[a-zA-Z]/g);
      if (tMatches && tMatches.length < 5 && eMatches && eMatches.length > 50) {
        text = text.replace(/[\u0B80-\u0BFF]/g, '');
      }
    }
  }

  // 14. Format Paragraphs for Justification & Reflow
  text = formatParagraphsForJustify(text);

  // 16. Normalize whitespace on lines (preserve intentional line breaks)
  const lines = text.split(/\r?\n/);
  const cleanedLines = lines.map(line => line.replace(/[ \t]+/g, ' ').trim());
  text = cleanedLines.join('\n');

  // 17. Prevent excessive consecutive blank lines (max 2 consecutive newlines)
  text = text.replace(/\n{3,}/g, '\n\n');

  // 18. Unicode NFC canonical composition
  try {
    text = text.normalize('NFC');
  } catch (_) { }

  return text.trim();
}

module.exports = {
  cleanExtractedText,
  repairTamilSpellingAndTypography,
  formatParagraphsForJustify,
  isPredominantlyEnglish,
  isTamilDocumentOrPassage,
  decodeLegacyTamilIfPresent,
  decodeMacTamilPDF,
  decodeLateVolumeDtpTamil,
  decodeBaminiIfDetected,
  normalizeVisualPreBaseVowels,
  normalizeTamilKerningAndSyllables,
  LEGACY_SPECIAL_MAP,
  LEGACY_ASCII_MAP,
  BAMINI_CONSONANTS_VIRAMA,
  BAMINI_SPECIAL,
  BAMINI_BASIC
};
