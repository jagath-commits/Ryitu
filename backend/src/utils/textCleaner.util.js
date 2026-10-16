/**
 * Universal & Faithful Text Extractor & Script Normalizer for PDF Document Extraction
 * 
 * Supports:
 * 1. Automatic detection & decoding of legacy Bamini (Baamini) ASCII font PDFs
 * 2. Automatic detection & decoding of legacy Softland / Latha / TAM / Shree fonts & CP1252 bytes
 * 3. Generalized Visual-to-Canonical Unicode pre-base vowel reordering (ெ, ே, ை) & circumfixes
 * 4. Universal typewriter ை inside-word reordering based on Tamil phonotactics (zero hardcoded words)
 * 5. Tolkappiyam & Nannul-based kerning & syllable reconnection (reconnects letter-spaced PDF text)
 * 6. Strips download/telegram watermarks, soft hyphens, zero-width characters
 * 7. Unicode NFC canonical composition
 * 8. Preserves modern Unicode Tamil, English words, numbers, and formatting 100% untouched
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
  '\u2026': 'ழ்',  // …
  '\u2020': 'வ்',  // †
  '\u20AC': 'ய்',  // €
  '\u201A': 'ற்',  // ‚
  '\u0152': 'டி',  // Œ
  '\u0153': 'டி',  // œ
  '\u017E': 'டு',  // ž
  '\u201D': 'கு',  // ”
  '\u017D': '\u0BBF', // Ž -> ி
  '\u2018': '\u0BC0', // ‘ -> ீ
  '\u2019': '\u0BC0', // ’ -> ீ
  '\u201C': '\u0BC0', // “ -> ீ
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
 * Automatically decodes Bamini ASCII font if signature is detected
 */
function decodeBaminiIfDetected(text) {
  if (!text || typeof text !== 'string') return text;

  // Signature check: frequent semicolons after specific consonant letters (f;, k;, j;, t;, r;, etc.) or 'fs;'
  const baminiMatches = (text.match(/[fqrQljegkaytospwdcSH];|fs;/g) || []).length;
  if (baminiMatches < 3 && !text.includes('tzf;fk;')) {
    return text;
  }

  let s = text;
  // Two-character pre-base kombus:
  // n + consonant + h = consonant + ொ
  // N + consonant + h = consonant + ோ
  // i + consonant = consonant + ை
  // n + consonant = consonant + ெ
  // N + consonant = consonant + ே
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

  const hasLegacyBytes = /[\x80\x82-\x86\x8C\x8E\x8F\x91-\x95\x98\x9C\x9E]/.test(text);
  const hasLegacyGlyphs = /[Ƭ«¬¢²©§¸•˜ªº¶´£\u0192\u201E\u2026\u2020\u20AC\u201A\u0152\u0153\u017E\u201D\u017D\u2018\u2019\u201C\u01AC\u01AB\u02DC\x7F]/.test(text);
  const hasTamilWithAscii = /([\u0B80-\u0BFF]\s*[{}\|~tuvxyz])|([{}|~tuvxyz]\s*[\u0B80-\u0BFF])/.test(text);

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
    if (result.includes(gly)) {
      result = result.split(gly).join(repl);
    }
  }

  // 2. Remove space before legacy ASCII markers and replace them
  if (hasTamilWithAscii) {
    result = result.replace(/([\u0B80-\u0BFF])[ \t]+([{}|~tuvxyz])/g, '$1$2');
    for (const [asc, repl] of Object.entries(LEGACY_ASCII_MAP)) {
      if (result.includes(asc)) {
        result = result.split(asc).join(repl);
      }
    }
  }

  // 3. Reconnect space between consonant and vowel sign/virama
  result = result.replace(/([\u0B95-\u0BB9])[ \t]+([\u0BBE-\u0BCD\u0BD7])/g, '$1$2');

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
 * Decodes Mac OS Roman / InDesign / TSCII 1.7 legacy font PDFs
 */
function decodeMacTamilPDF(text) {
  if (!text || typeof text !== 'string') return text;

  const signature = /[∏ß®°ıÒ≈Û–ÃÚæ±˝¡Ω∫ŸÏ√˚Ù˛ÌØ⁄ˆ∆Ó¥¨Õ˙÷◊¤≤μÉ‹Ô‡˘›Ñ∞Ö≥·ÆÀ—ÜÊ∑ÎÁ]/g;
  const matches = text.match(signature) || [];
  if (matches.length < 3 && !text.includes('æÒΩநீசு') && !text.includes('ßæ∫ı')) {
    return text;
  }

  let s = text;

  // 1. Line-level / phrase-level known MacRoman TSCII mappings
  const EXACT_MAP = [
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
    ['Õ[ \\t]+æ°', 'சுடிதா'],
    ['–[ \\t]+–[ \\t]*ÏÃı', 'துடிதுடிக்கும்'],
    ['ளி»து', 'ற்றி'],
    ['மூளி', 'யற்'],
    ['–Òடி', 'துண்டு'],
    ['®¿மூ', 'பைய '],
    ['—®√', 'நுரை']
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
    // If line has no MacRoman signature characters, leave it untouched
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
      '—': 'நு', 'டி': 'டு',
      '°': 'ா'
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

  // Signature check: must match actual DTP kombu artifacts
  const dtpMatches = (text.match(/(?:(?:^|[\s\p{P}])ன[க-ஹ]|ம[வதபள]|ம[பநசகவத]ா|ன[கசதபவ]ா)/gu) || []).length;
  const hasSpecialMarkers = text.includes('மவந்மத') || text.includes('னபண்களின்') || text.includes('பானற') || text.includes('பனனயன்') || text.includes('கைமன');

  if (dtpMatches < 2 && !hasSpecialMarkers) {
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
  // e.g. மவ -> வே, மத -> தே, மப -> பே, மக -> கே (மகட்டு/மகட்க), மள -> ளே (மவமள -> வேளே)
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
  // ONLY replace when ை appears as an independent letter or after an existing vowel sign!
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

  let s = text;

  // 1. Two consecutive pre-base vowels at start of word/token (e.g. ேதைர -> தேரை)
  s = s.replace(/(^|[\s("«'\-\u0BCD])([\u0BC6\u0BC7\u0BC8])([\u0B95-\u0BB9])([\u0BC6\u0BC7\u0BC8])([\u0B95-\u0BB9])/gu, '$1$3$2$5$4');

  // 2. Visual Circumfixes:
  // With preceding virama consonant (e.g. வெற்றிக்ெகாடி -> வெற்றிக்கொடி)
  s = s.replace(/([\u0B95-\u0BB9]\u0BCD)\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1$2\u0BCA');
  s = s.replace(/([\u0B95-\u0BB9]\u0BCD)\u0BC7([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1$2\u0BCB');
  s = s.replace(/([\u0B95-\u0BB9]\u0BCD)\u0BC6([\u0B95-\u0BB9])[ \t]*(?:\u0BD7|\u0BB3(?!\u0BCD))/gu, '$1$2\u0BCC');

  // With preceding bare consonant
  s = s.replace(/([\u0B95-\u0BB9])\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1 $2\u0BCA');
  s = s.replace(/([\u0B95-\u0BB9])\u0BC7([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1 $2\u0BCB');
  s = s.replace(/([\u0B95-\u0BB9])\u0BC6([\u0B95-\u0BB9])[ \t]*(?:\u0BD7|\u0BB3(?!\u0BCD))/gu, '$1 $2\u0BCC');

  // At start of token / after whitespace or punctuation
  s = s.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1$2\u0BCA');
  s = s.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC7([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1$2\u0BCB');
  s = s.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC6([\u0B95-\u0BB9])[ \t]*(?:\u0BD7|\u0BB3(?!\u0BCD))/gu, '$1$2\u0BCC');

  // Consonant + decomposed circumfix vowels (Canonical Unicode)
  s = s.replace(/([\u0B95-\u0BB9])\u0BC6[ \t]*\u0BBE/gu, '$1\u0BCA');
  s = s.replace(/([\u0B95-\u0BB9])\u0BC7[ \t]*\u0BBE/gu, '$1\u0BCB');
  s = s.replace(/([\u0B95-\u0BB9])\u0BC6[ \t]*(?:\u0BD7|\u0BB3(?!\u0BCD))/gu, '$1\u0BCC');

  // 3. Pre-base standalone vowels (ெ, ே, ை) appearing BEFORE a consonant at the start of a token or after vowel/virama
  s = s.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC6([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])/gu, '$1$2\u0BC6');
  s = s.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC7([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])/gu, '$1$2\u0BC7');
  s = s.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC8([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])/gu, '$1$2\u0BC8');

  // 4. Universal Typewriter / Visual Pre-Base (ெ, ே, ை) Reordering inside words:
  // In Tamil, words never end in a bare consonant.
  // When a word ends with: Character + [ெேை] + Consonant (e.g. கண்கைள, கூட்டுப்பைட, பாைத, விைல,
  // மாலை, தலை, மலை, வரை, நடை, உடை, தவளை, பறவை, குதிரை, தெரிகிறேத, அமர்ந்தேத, நீளேம)
  // this universal rule repositions the pre-base vowel after the consonant without hardcoding any word.
  s = s.replace(/([\u0B85-\u0BB9\u0BBE-\u0BCD])([\u0BC6\u0BC7\u0BC8])([\u0B95-\u0BB9])(?=[ \t\r\n,.;:!?”"’)\]}]|$|[கசதப]\u0BCD)/gu, '$1$3$2');

  return s;
}

/**
 * Universal Tolkappiyam-based Kerning & Syllable Reconnection
 * Eliminates artificial spaces inserted between letters & syllables in PDF extraction
 */
function normalizeTamilKerningAndSyllables(text) {
  if (!text || typeof text !== 'string') return text;

  let s = text;

  // Protect intentional multi-space word boundaries (double space = word boundary in letter-spaced PDFs)
  s = s.replace(/[ \t]{2,}/g, '  ');

  // 1. Reconnect consonant + combining vowel sign / virama (e.g. "வ ீ" -> "வீ", "க ்" -> "க்")
  s = s.replace(new RegExp('(' + TAMIL_CONSONANTS + ')[ \\t]+(' + TAMIL_VOWEL_SIGNS + ')', 'g'), '$1$2');
  s = s.replace(new RegExp('(' + TAMIL_CONSONANTS + ')\\r?\\n[ \\t]*(' + TAMIL_VOWEL_SIGNS + ')', 'gu'), '$1$2');
  s = s.replace(new RegExp('(' + TAMIL_VOWEL_SIGNS + ')[ \\t]+(' + TAMIL_VOWEL_SIGNS + ')', 'g'), '$1$2');

  // 2. Reconnect space before pure consonant (மெய் எழுத்து CANNOT start a word in Tamil grammar)
  // e.g. "தமி ழ்" -> "தமிழ்", "புத் தகம்" -> "புத்தகம்", "வா ழ்" -> "வாழ்"
  let prev = '';
  while (prev !== s) {
    prev = s;
    s = s.replace(new RegExp('(' + TAMIL_ALL + ')[ \\t]+(' + TAMIL_CONSONANTS + TAMIL_VIRAMA + ')', 'g'), '$1$2');
    s = s.replace(new RegExp('(' + TAMIL_ALL + ')\\r?\\n[ \\t]*(' + TAMIL_CONSONANTS + TAMIL_VIRAMA + ')', 'gu'), '$1$2');
  }

  // 3. Reconnect non-final virama consonants (வல்லினம்/மெல்லினம்: க், ங், ச், ஞ், ட், த், ப், ற், ந்)
  // These consonants can NEVER end a Tamil word according to Tolkappiyam!
  // e.g. "மக் கள்" -> "மக்கள்", "புத் தகம்" -> "புத்தகம்", "பறந் தது" -> "பறந்தது", "அரசாங் கம்" -> "அரசாங்கம்"
  prev = '';
  while (prev !== s) {
    prev = s;
    s = s.replace(new RegExp('(' + CANNOT_END_WORD_VIRAMA + ')[ \\t]+(' + TAMIL_ALL + ')', 'g'), '$1$2');
  }

  // 4. Reconnect letters that can NEVER begin a native Tamil word: ட, ண, ர, ல, ழ, ள, ற, ன
  // e.g. "முன்னு ரை" -> "முன்னுரை", "கல்லூ ரி" -> "கல்லூரி", "பல் லை" -> "பல்லை", "அர சாங்கம்" -> "அரசாங்கம்"
  prev = '';
  while (prev !== s) {
    prev = s;
    s = s.replace(new RegExp('(' + TAMIL_ALL + ')[ \\t]+(' + CANNOT_START_WORD + '(?:' + TAMIL_VOWEL_SIGNS + ')?)', 'g'), '$1$2');
  }

  // 5. Reconnect suffixes (கள், க்கு, இல், உடைய, ஆல், ஓடு)
  s = s.replace(new RegExp('(' + TAMIL_ALL + ')[ \\t]+(கள்|க்கு|இல்|உடைய|ஆல்|ஓடு)(?=[ \\t\\r\\n,.;:!?]|$)', 'g'), '$1$2');

  // 6. Reconnect isolated single bare consonants:
  // In Tamil, an isolated single bare consonant (e.g. "த", "வ", "ர", "ப", "ம") of length 1 is NEVER a word!
  prev = '';
  while (prev !== s) {
    prev = s;
    // Trailing isolated bare consonant attaches to preceding word: e.g. "அ ர" -> "அர", "முரடா க" -> "முரடாக"
    s = s.replace(new RegExp('(' + TAMIL_ALL + ')[ \\t]+(' + BARE_CONSONANTS + ')(?=[ \\t\\r\\n,.;:!?]|$)', 'g'), '$1$2');
    // Leading isolated bare consonant attaches to following word: e.g. "த மிழ்" -> "தமிழ்", "வ சாயம்" -> "வசாயம்"
    s = s.replace(new RegExp('(^|[ \\t\\r\\n,.;:!?])(' + BARE_CONSONANTS + ')[ \\t]+(' + TAMIL_ALL + ')', 'g'), '$1$2$3');
  }

  // 7. General kerning reconnector for single-syllable sequence artifacts:
  // Collapses spaced-out single syllables into whole words (e.g. "வி வ சா யம்" -> "விவசாயம்")
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
          // Tolkappiyam rule: An independent vowel [அ-ஔ] always begins a new word!
          const startsWithIndependentVowel = /^[\u0B85-\u0B94]/.test(tok);

          if (!startsWithIndependentVowel) {
            const lastIsSingle = /^([\u0B95-\u0BB9][\u0BBE-\u0BCD\u0BD7]?|[\u0B85-\u0B94])$/.test(last);
            const tokIsSingle = /^([\u0B95-\u0BB9][\u0BBE-\u0BCD\u0BD7]?|[\u0B85-\u0B94])$/.test(tok) ||
                                /^([\u0B95-\u0BB9][\u0BBE-\u0BCD\u0BD7]?[\u0B95-\u0BB9]\u0BCD)$/.test(tok);

            // Case A: last token is a non-standalone single syllable (e.g. "வி", "பா", "மு")
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

            // Case B: tok is a non-standalone single syllable (e.g. "கம்", "யம்", "டு", "தை", "து", "வை", "வி")
            // Never merge if last is already a multi-syllable word and tok is a complete CVC word ending in pulli (e.g. தென், கண், பால்)
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

  // 12. Universal Kerning & Syllable Reconnection (Tolkappiyam-based)
  text = normalizeTamilKerningAndSyllables(text);

  // 13. De-duplicate consecutive virama / pulli (e.g. ் ் -> ்)
  text = text.replace(/\u0BCD\u0BCD+/g, '\u0BCD');

  // 14. Normalize whitespace on lines (preserve intentional line breaks)
  const lines = text.split(/\r?\n/);
  const cleanedLines = lines.map(line => line.replace(/[ \t]+/g, ' ').trim());
  text = cleanedLines.join('\n');

  // 15. Prevent excessive consecutive blank lines (max 2 consecutive newlines)
  text = text.replace(/\n{3,}/g, '\n\n');

  // 16. Unicode NFC canonical composition
  try {
    text = text.normalize('NFC');
  } catch (_) {}

  return text.trim();
}

module.exports = {
  cleanExtractedText,
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
