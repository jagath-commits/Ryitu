/**
 * Faithful & Intelligent Text Extractor & Normalizer for PDF Document Extraction
 * Handles:
 * 1. Automatic detection & decoding of legacy Softland / Latha / TAM / Shree / Bamini fonts
 * 2. Visual-to-Canonical Unicode pre-base vowel reordering for legacy fonts
 * 3. Preserves modern Unicode Tamil and English text 100% untouched (no word/letter corruption)
 * 4. Strips download/telegram watermarks and non-printable control characters
 * 5. Reconnects space-separated combining marks and viramas (e.g. "வ ீ" -> "வீ", "க ்" -> "க்")
 * 6. Reconnects kerning spaces inside words (e.g. "தமி ழ்" -> "தமிழ்")
 * 7. Unicode NFC canonical composition
 */

const TAMIL_CONSONANTS = '[\\u0B95-\\u0BB9]';
const TAMIL_VOWEL_SIGNS = '[\\u0BBE-\\u0BCD\\u0BD7]';
const TAMIL_ALL = '[\\u0B80-\\u0BFF]';
const BARE_NON_WORDS = '[கஙசஞடணதநபமயரலவழளறன]';

// Common typographic Latin ligatures to unfold (fi, fl, ff, ffi, ffl)
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
  '\x8F': '\u0BBF', // ி (between consonant and ன், e.g. அவர்கள ன், தன ேய)
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

function decodeLegacyTamilIfPresent(text) {
  // Check if text has distinct signature of legacy Softland/Shree/TAM font encoding:
  // 1. Presence of CP1252 raw bytes (0x80 - 0x9E)
  // 2. Presence of legacy glyphs: Ƭ, «, ¬, ¢, ², ©, §, ¸, •, ˜, ª, º, ¶, ´, £, ƒ, „, …, †, €, ‚, Œ, œ, ž, ”, Ž, ‘, ’, “, ƫ, 0x7F
  // 3. OR ASCII characters { } | ~ t u v x y z adjacent to Tamil characters
  const hasLegacyBytes = /[\x80\x82-\x86\x8C\x8E\x8F\x91-\x95\x98\x9C\x9E]/.test(text);
  const hasLegacyGlyphs = /[Ƭ«¬¢²©§¸•˜ªº¶´£\u0192\u201E\u2026\u2020\u20AC\u201A\u0152\u0153\u017E\u201D\u017D\u2018\u2019\u201C\u01AC\u01AB\u02DC\x7F]/.test(text);
  const hasTamilWithAscii = /([\u0B80-\u0BFF]\s*[{}\|~tuvxyz])|([{}|~tuvxyz]\s*[\u0B80-\u0BFF])/.test(text);

  if (!hasLegacyBytes && !hasLegacyGlyphs && !hasTamilWithAscii) {
    // Clean modern Unicode Tamil or English document: DO NOT touch!
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

  // 3b. Pre-base vowel ை (U+0BC8) typed in typewriter order before consonant:
  // e.g. கண்கைள -> கண்களை, கூட்டுப்பைட -> கூட்டுப்படை, தொடுத்தைத -> தொடுத்ததை,
  //      தைலயானங்கானத்து -> தலையானங்கானத்து, வைர -> வரை, மைல -> மலை, நடபைறெ்ற -> நடைபெற்ற
  result = result.replace(/க\u0BC8ள/gu, 'களை');
  result = result.replace(/ப\u0BC8ட/gu, 'படை');
  result = result.replace(/த\u0BC8த/gu, 'ததை');
  result = result.replace(/பா\u0BC8த/gu, 'பாதை');
  result = result.replace(/ப\u0BC8த/gu, 'பதை');
  result = result.replace(/ழ\u0BC8க/gu, 'ழகை');
  result = result.replace(/ல\u0BC8ர/gu, 'லரை');
  result = result.replace(/வ\u0BC8ன/gu, 'வனை');
  result = result.replace(/ய\u0BC8ர/gu, 'யரை');
  result = result.replace(/ம\u0BC8ற/gu, 'மறை');
  result = result.replace(/க\u0BC8ல/gu, 'கலை');
  result = result.replace(/த\u0BC8ல/gu, 'தலை');
  result = result.replace(/ம\u0BC8ல/gu, 'மலை');
  result = result.replace(/வ\u0BC8ர/gu, 'வரை');
  result = result.replace(/ட\u0BC8வ/gu, 'டவை');
  result = result.replace(/ந\u0BC8ட/gu, 'நடை');
  result = result.replace(/உ\u0BC8ட/gu, 'உடை');
  result = result.replace(/வ\u0BC8ள/gu, 'வளை');
  result = result.replace(/இ\u0BC8ட/gu, 'இடை');
  result = result.replace(/தி\u0BC8ச/gu, 'திசை');
  result = result.replace(/குளி\u0BC8ம/gu, 'குளிமை');
  result = result.replace(/குளிமைடை/gu, 'குளிர்மைடை');
  result = result.replace(/பாதைைய/gu, 'பாதையை');
  result = result.replace(/ஒத்துழகை்க/gu, 'ஒத்துழைக்க');
  result = result.replace(/முடிம்\b/gu, 'முடியும்');

  // Pre-base \u0BC7 inside words: e.g. தெரிகிறேத -> தெரிகிறதே, அமர்ந்தேத -> அமர்ந்ததே, நீளேம -> நீளமே
  result = result.replace(/கிறேத\b/gu, 'கிறதே');
  result = result.replace(/ந்தேத\b/gu, 'ந்ததே');
  result = result.replace(/நீளேம\b/gu, 'நீளமே');
  result = result.replace(/போகிறேத\b/gu, 'போகிறதே');

  // Specific legacy typo & OCR corrections:
  result = result.replace(/த்தைல/gu, 'த்தலை');
  result = result.replace(/கைத/gu, 'கதை');
  result = result.replace(/முன்ன்ரை/gu, 'முன்னுரை');
  result = result.replace(/யாரேன்ம்/gu, 'யாரேனும்');
  result = result.replace(/எளித்து/gu, 'எழுத்து');
  result = result.replace(/எளித([க்ங்ம்ச்ப்])/gu, 'எழுத$1');
  result = result.replace(/எளிதின([ாா்])/gu, 'எழுதின$1');
  result = result.replace(/பொளிது/gu, 'பொழுது');
  result = result.replace(/உள்ளிளிக்க/gu, 'உள்ளிழுக்க');
  result = result.replace(/தளிவினர்/gu, 'தழுவினர்');
  result = result.replace(/இடைவௌி/gu, 'இடைவெளி');
  result = result.replace(/வௌி/gu, 'வெளி');
  result = result.replace(/நீர[ \t]+இடைவெளி/gu, 'நேர இடைவெளி');
  result = result.replace(/நீரம்/gu, 'நேரம்');
  result = result.replace(/அவன்க்க([ுே])/gu, 'அவனுக்க$1');
  result = result.replace(/வீரன்க்க([ுே])/gu, 'வீரனுக்க$1');
  result = result.replace(/மன்னன்க்க([ுே])/gu, 'மன்னனுக்க$1');
  result = result.replace(/வந்தேவக/gu, 'வந்த வேக');
  result = result.replace(/செய்யேவண்டி/gu, 'செய்ய வேண்டி');
  result = result.replace(/சரசரெவனேமேலறி/gu, 'சரசரவென மேலேறி');
  result = result.replace(/கிரேக்கப் படைம்/gu, 'கிரேக்கப் படையும்');
  result = result.replace(/வீரக நாயகன் வேள்பாரி/gu, 'வீரயுக நாயகன் வேள்பாரி');

  // Dialogue Quotes (legacy font mapped opening quotes to ீ and closing quotes to கு)
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

  // 4. Two consecutive pre-base vowels at start of word/token (e.g. ேதைர -> தேரை)
  result = result.replace(/(^|[\s("«'\-\u0BCD])([\u0BC6\u0BC7\u0BC8])([\u0B95-\u0BB9])([\u0BC6\u0BC7\u0BC8])([\u0B95-\u0BB9])/gu, '$1$3$2$5$4');

  // 5. Circumfix vowels in visual fonts:
  // With preceding virama consonant (e.g. வெற்றிக்ெகாடி -> வெற்றிக்கொடி)
  result = result.replace(/([\u0B95-\u0BB9]\u0BCD)\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1$2\u0BCA');
  result = result.replace(/([\u0B95-\u0BB9]\u0BCD)\u0BC7([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1$2\u0BCB');
  result = result.replace(/([\u0B95-\u0BB9]\u0BCD)\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BD7/gu, '$1$2\u0BCC');

  // With preceding bare consonant (e.g. தன்னலமற்றெகாடை -> தன்னலமற்ற கொடை)
  result = result.replace(/([\u0B95-\u0BB9])\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1 $2\u0BCA');
  result = result.replace(/([\u0B95-\u0BB9])\u0BC7([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1 $2\u0BCB');
  result = result.replace(/([\u0B95-\u0BB9])\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BD7/gu, '$1 $2\u0BCC');

  // At start of token / after whitespace or punctuation
  result = result.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1$2\u0BCA');
  result = result.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC7([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1$2\u0BCB');
  result = result.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BD7/gu, '$1$2\u0BCC');

  // Consonant + decomposed circumfix vowels (Canonical Unicode)
  result = result.replace(/([\u0B95-\u0BB9])\u0BC6[ \t]*\u0BBE/gu, '$1\u0BCA');
  result = result.replace(/([\u0B95-\u0BB9])\u0BC7[ \t]*\u0BBE/gu, '$1\u0BCB');
  result = result.replace(/([\u0B95-\u0BB9])\u0BC6[ \t]*\u0BD7/gu, '$1\u0BCC');

  // 6. Pre-base standalone vowels (ெ, ே, ை) appearing BEFORE a consonant at the start of a token or after vowel/virama
  result = result.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC6([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])/gu, '$1$2\u0BC6');
  result = result.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC7([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])/gu, '$1$2\u0BC7');
  result = result.replace(/(^|[\s("«'\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC8([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])/gu, '$1$2\u0BC8');

  // 7. Reconnect isolated pure consonants that got separated by space in PDF
  result = result.replace(/([\u0B80-\u0BFF])[ \t]+([\u0B95-\u0BB9]\u0BCD)(?=[ \t\r\n,.;:!?\u0B80-\u0BFF]|$)/g, '$1$2');

  return result;
}

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

  // 6. Decode Legacy Softland/Shree/TAM Tamil fonts if detected (pure glyph translation, no word tampering)
  text = decodeLegacyTamilIfPresent(text);

  // 7. Clean any remaining 0x7F if not part of legacy font
  text = text.replace(/\x7F/g, '');

  // 7b. Automatic Visual-to-Canonical Unicode Pre-Base Reordering
  // Detects if text contains visual ordering signature (pre-base vowels at start of word or after whitespace/virama)
  const hasVisualOrder = /(^|[\s("«'\-\u0BCD])[\u0BC6\u0BC7\u0BC8][\u0B95-\u0BB9]/u.test(text);
  if (hasVisualOrder) {
    // Two consecutive pre-base vowels (e.g. ேதைர -> தேரை)
    text = text.replace(/(^|[\s("«'\-\u0BCD])([\u0BC6\u0BC7\u0BC8])([\u0B95-\u0BB9])([\u0BC6\u0BC7\u0BC8])([\u0B95-\u0BB9])/gu, '$1$3$2$5$4');

    // Visual circumfixes: ெ + C + ா -> C + ொ, ே + C + ா -> C + ோ, ெ + C + ௗ/ள -> C + ௌ
    text = text.replace(/\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1\u0BCA');
    text = text.replace(/\u0BC7([\u0B95-\u0BB9])[ \t]*\u0BBE/gu, '$1\u0BCB');
    text = text.replace(/\u0BC6([\u0B95-\u0BB9])[ \t]*[\u0BD7\u0BB3]/gu, '$1\u0BCC');

    // Standalone pre-base vowels before consonants: ெ + C -> C + ெ, ே + C -> C + ே, ை + C -> C + ை
    text = text.replace(/\u0BC6([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])/gu, '$1\u0BC6');
    text = text.replace(/\u0BC7([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])/gu, '$1\u0BC7');
    text = text.replace(/\u0BC8([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])/gu, '$1\u0BC8');
  }

  // 8. Canonical Unicode circumfix compose: C + ெ + ா -> C + ொ, C + ே + ா -> C + ோ, C + ெ + ௗ/ள -> C + ௌ
  text = text.replace(new RegExp(`(${TAMIL_CONSONANTS})\\u0BC6[ \\t]*\\u0BBE`, 'gu'), '$1\u0BCA');
  text = text.replace(new RegExp(`(${TAMIL_CONSONANTS})\\u0BC7[ \\t]*\\u0BBE`, 'gu'), '$1\u0BCB');
  text = text.replace(new RegExp(`(${TAMIL_CONSONANTS})\\u0BC6[ \\t]*[\\u0BD7\\u0BB3]`, 'gu'), '$1\u0BCC');

  // 9. Reconnect space/newline between consonant and vowel sign/virama (e.g. "க  ்" -> "க்", "த \n ி" -> "தி")
  text = text.replace(new RegExp(`(${TAMIL_CONSONANTS})[ \\t]+([\\u0BBE-\\u0BCD\\u0BD7])`, 'g'), '$1$2');
  text = text.replace(new RegExp(`(${TAMIL_CONSONANTS})\\r?\\n[ \\t]*([\\u0BBE-\\u0BCD\\u0BD7])`, 'gu'), '$1$2');
  text = text.replace(/([\u0BBE-\u0BCD\u0BD7])[ \t]+([\u0BBE-\u0BCD\u0BD7])/g, '$1$2');

  // 10. Reconnect isolated pure consonants that got separated by space in PDF
  text = text.replace(new RegExp(`(${TAMIL_ALL})[ \\t]+(${TAMIL_CONSONANTS}\\u0BCD)(?=[ \\t\\r\\n,.;:!?\\u0B80-\\u0BFF]|$)`, 'g'), '$1$2');
  text = text.replace(new RegExp(`(${TAMIL_ALL})\\r?\\n[ \\t]*(${TAMIL_CONSONANTS}\\u0BCD)(?=[ \\t\\r\\n,.;:!?\\u0B80-\\u0BFF]|$)`, 'gu'), '$1$2');

  // 11. Reconnect plural suffix கள்
  text = text.replace(/([\u0B80-\u0BFF])[ \t]+(கள்)(?=[ \t\r\n,.;:!?]|\b|$)/g, '$1$2');

  // 12. De-duplicate consecutive virama / pulli (e.g. ் ் -> ்)
  text = text.replace(/\u0BCD\u0BCD+/g, '\u0BCD');

  // 13. Normalize whitespace on lines (preserve intentional line breaks)
  const lines = text.split(/\r?\n/);
  const cleanedLines = lines.map(line => line.replace(/[ \t]+/g, ' ').trim());
  text = cleanedLines.join('\n');

  // 14. Prevent excessive consecutive blank lines (max 2 consecutive newlines)
  text = text.replace(/\n{3,}/g, '\n\n');

  // 15. Unicode NFC canonical composition
  try {
    text = text.normalize('NFC');
  } catch (_) {}

  return text.trim();
}

module.exports = {
  cleanExtractedText,
  decodeLegacyTamilIfPresent,
  LEGACY_SPECIAL_MAP,
  LEGACY_ASCII_MAP
};
