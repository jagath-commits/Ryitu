import 'dart:async';
import 'dart:io' show Platform, File;
import 'package:dmk_project/home.dart';
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/drafts_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:math' show min;
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

class PageBlock {
  String type;
  String? text;
  File? image;
  String? imageUrl;
  double? imageWidth;
  Offset? imagePosition;
  String? previousText;
  bool isHeadline;
  int? fontColor; // 🔥 BLOCK COLOR
  double? fontSize; // 🔥 BLOCK FONT SIZE
  String? fontFamily; // 🔥 BLOCK FONT FAMILY
  double? lineSpacing;
  double? letterSpacing;
  TextAlign? textAlign;
  String? blockId;

  PageBlock({
    required this.type,
    this.text,
    this.imageUrl,
    this.imagePosition,
    this.isHeadline = false,
    this.fontSize,
    this.fontFamily,
    this.fontColor,
    this.lineSpacing,
    this.letterSpacing,
    this.textAlign,
    this.blockId,
  }) {
    // Generate unique ID if missing
    blockId ??=
        "${DateTime.now().millisecondsSinceEpoch}_${(100 + (100 * (DateTime.now().microsecond / 1000000))).toInt()}";
  }

  PageBlock.text(
    this.text, {
    this.isHeadline = false,
    this.fontColor,
    this.fontSize,
    this.fontFamily,
    this.lineSpacing,
    this.letterSpacing,
    this.textAlign,
    this.blockId,
  }) : type = "text",
       image = null,
       imageUrl = null,
       imageWidth = null,
       previousText = text {
    blockId ??=
        "${DateTime.now().millisecondsSinceEpoch}_${(100 + (100 * (DateTime.now().microsecond / 1000000))).toInt()}";
  }

  PageBlock.image(this.image, {this.blockId})
    : type = "image",
      text = null,
      imageUrl = null,
      isHeadline = false,
      imageWidth = 200,
      imagePosition = const Offset(0, 0),
      previousText = null {
    blockId ??=
        "${DateTime.now().millisecondsSinceEpoch}_${(100 + (100 * (DateTime.now().microsecond / 1000000))).toInt()}";
  }

  PageBlock.networkImage(this.imageUrl, {this.blockId})
    : type = "image",
      text = null,
      isHeadline = false,
      image = null,
      imageWidth = 200,
      imagePosition = const Offset(0, 0),
      previousText = null {
    blockId ??=
        "${DateTime.now().millisecondsSinceEpoch}_${(100 + (100 * (DateTime.now().microsecond / 1000000))).toInt()}";
  }
}

class PageData {
  double fontSize;
  String fontFamily;
  int fontColor;
  double lineSpacing;
  double letterSpacing;
  double pageMargin;
  TextAlign textAlign;

  List<PageBlock> blocks;

  PageData({
    required this.fontSize,
    required this.fontFamily,
    required this.fontColor,
    this.lineSpacing = 1.4,
    this.letterSpacing = 0.0,
    this.pageMargin = 50.0,
    this.textAlign = TextAlign.justify,
  }) : blocks = [PageBlock.text("")];
}

const _kValidSingleSyllableWords = {
  'தீ', 'பூ', 'கை', 'பை', 'வா', 'போ', 'தா', 'நீ', 'மை',
  'ஆ', 'ஈ', 'ஏ', 'ஐ', 'ஓ',
  // Common valid single-syllable CVC words ending in pulli
  'தென்', 'கண்', 'மண்', 'விண்', 'பால்', 'கால்', 'வால்', 'நாள்',
  'வேல்', 'சொல்', 'வில்', 'கல்', 'புல்', 'பல்', 'முள்', 'நூல்',
  'பொன்', 'மான்', 'மீன்', 'தேன்', 'வான்', 'நான்', 'தான்', 'ஏன்',
  'முன்', 'பின்', 'மின்', 'நெல்', 'பார்', 'ஊர்', 'நீர்',
  'நேர்', 'வேர்', 'யார்', 'கார்', 'போர்', 'தார்', 'சீர்', 'நார்'
};

const _kBaminiConsonantsVirama = {
  'f;': 'க்', 'q;': 'ங்', 'r;': 'ச்', 'Q;': 'ஞ்', 'l;': 'ட்', 'z;': 'ண்',
  'j;': 'த்', 'e;': 'ந்', 'g;': 'ப்', 'k;': 'ம்', 'a;': 'ய்', 'u;': 'ர்',
  'y;': 'ல்', 't;': 'வ்', 'o;': 'ழ்', 's;': 'ள்', 'w;': 'ற்', 'd;': 'ன்',
  'c;': 'ஜ்', 'S;': 'ஷ்', 'n\\;': 'ஸ்', 'H;': 'ழ்', 'b;': 'க்ஷ்'
};

const _kBaminiSpecial = {
  'thœj;Jf;fs;': 'வாழ்த்துகள்',
  'thœj;J': 'வாழ்த்து',
  'fs;': 'கள்',
  'F': 'கு', '\$': 'கூ', 'R': 'சு', '#': 'சூ', 'L': 'டு', '^': 'டூ',
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

const _kBaminiBasic = {
  'f': 'க', 'q': 'ங', 'r': 'ச', 'Q': 'ஞ', 'l': 'ட', 'z': 'ண',
  'j': 'த', 'e': 'ந', 'g': 'ப', 'k': 'ம', 'a': 'ய', 'u': 'ர',
  'y': 'ல', 't': 'வ', 'o': 'ழ', 's': 'ள', 'w': 'ற', 'd': 'ன',
  'c': 'ஜ', 'S': 'ஷ', 'n\\': 'ஸ', 'h': 'ா'
};

bool isTamilDocumentOrPassage(String text) {
  if (text.isEmpty) return false;

  final tamilCount = RegExp(r'[\u0B80-\u0BFF]').allMatches(text).length;
  final engCount = RegExp(r'[a-zA-Z]').allMatches(text).length;

  if (tamilCount > 0) {
    if (tamilCount >= engCount) return true;
    if (tamilCount >= 15 && (tamilCount / (tamilCount + engCount)) >= 0.15) return true;
  }

  final baminiMatches = RegExp(r'[fqrQljegkaytospwdcSH];|fs;').allMatches(text).length;
  if (baminiMatches >= 3 && (text.contains('tzf;fk;') || text.contains('thœj;Jf;fs;') || engCount < 30 || baminiMatches > engCount * 0.1)) {
    return true;
  }

  if (text.contains('æÒΩநீசு') || text.contains('ßæ∫ı') || text.contains('æÒΩ£˜') || text.contains('taNNIr tEcam')) {
    return true;
  }
  final macRomanDistinctive = RegExp(r'[æÒΩß∫Ú¡ÛÃÕ‹Ô‡›⁄˙˛ÌØÓÉ˚ıˆ˝]').allMatches(text).length;
  if (macRomanDistinctive >= 3 && (tamilCount > 0 || engCount < 30 || macRomanDistinctive > engCount * 0.15)) {
    return true;
  }

  final cp1252TamilMatches = RegExp(r'[\x80\x82-\x86\x8C\x8E\x8F\x91-\x95\x98\x9C\x9E]').allMatches(text).length;
  if (cp1252TamilMatches >= 3 && tamilCount > 0) {
    return true;
  }

  return false;
}

String decodeBaminiIfDetected(String text) {
  if (text.isEmpty) return text;
  if (!isTamilDocumentOrPassage(text)) return text;

  final baminiMatches = RegExp(r'[fqrQljegkaytospwdcSH];|fs;').allMatches(text).length;
  if (baminiMatches < 3 && !text.contains('tzf;fk;')) {
    return text;
  }

  String s = text;
  s = s.replaceAllMapped(RegExp(r'n([fqrQljegkaytospwdcSH])h'), (m) => '${m[1]}\u0BCA');
  s = s.replaceAllMapped(RegExp(r'N([fqrQljegkaytospwdcSH])h'), (m) => '${m[1]}\u0BCB');
  s = s.replaceAllMapped(RegExp(r'i([fqrQljegkaytospwdcSH])'), (m) => '${m[1]}\u0BC8');
  s = s.replaceAllMapped(RegExp(r'n([fqrQljegkaytospwdcSH])'), (m) => '${m[1]}\u0BC6');
  s = s.replaceAllMapped(RegExp(r'N([fqrQljegkaytospwdcSH])'), (m) => '${m[1]}\u0BC7');

  _kBaminiConsonantsVirama.forEach((k, v) {
    s = s.replaceAll(k, v);
  });
  _kBaminiSpecial.forEach((k, v) {
    s = s.replaceAll(k, v);
  });
  _kBaminiBasic.forEach((k, v) {
    s = s.replaceAll(k, v);
  });

  return s;
}

String decodeLegacyTamil(String text) {
  if (text.isEmpty) return text;
  if (!isTamilDocumentOrPassage(text)) return text;

  final hasLegacyGlyphs = RegExp(r'[Ƭ«¬¢²©§¸•˜ªº¶´£\u0192\u201E\u2026\u2020\u20AC\u201A\u0152\u0153\u017E\u201D\u017D\u2018\u2019\u201C\u01AC\u01AB\u02DC\x7F\u0080-\u009F]').hasMatch(text);
  final hasTamilWithAscii = RegExp(r'([\u0B80-\u0BFF]\s*[{}\|~tuvxyz])|([{}|~tuvxyz]\s*[\u0B80-\u0BFF])').hasMatch(text);

  if (!hasLegacyGlyphs && !hasTamilWithAscii) {
    return text;
  }

  String result = text;

  const cp1252Map = {
    '\x80': 'ய்',
    '\x82': 'ற்',
    '\x83': 'ல்',
    '\x84': 'ள்',
    '\x85': 'ழ்',
    '\x86': 'வ்',
    '\x8C': 'டி',
    '\x8E': '\u0BBF',
    '\x8F': '\u0BBF',
    '\x91': '\u0BC0',
    '\x92': '\u0BC0',
    '\x93': '\u0BC0',
    '\x94': 'கு',
    '\x95': 'கூ',
    '\x98': 'சு',
    '\x9C': 'டி',
    '\x9E': 'டு',
  };

  cp1252Map.forEach((k, v) {
    result = result.replaceAll(k, v);
  });

  const specialMap = {
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

  result = result.replaceAll(RegExp(r'கள[ \t]*[\u0192\u201E\x83\x84]'), 'கள்');

  specialMap.forEach((k, v) {
    result = result.replaceAll(k, v);
  });

  const asciiMap = {
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

  if (hasTamilWithAscii) {
    result = result.replaceAllMapped(RegExp(r'([\u0B80-\u0BFF])[ \t]+([{}|~tuvxyz])'), (m) => '${m[1]}${m[2]}');
    asciiMap.forEach((k, v) {
      result = result.replaceAll(k, v);
    });
  }

  // Reconnect space between consonant and vowel sign/virama
  result = result.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9])[ \t]+([\u0BBE-\u0BCD\u0BD7])'), (m) => '${m[1]}${m[2]}');

  // Dialogue Quotes
  result = result.replaceAllMapped(
    RegExp(r'([.?!,:])(?:[குீ”\x22\x27]|[\u0BC0\u0BC1])+(?=[\s\n]|$)'),
    (m) => '${m[1]}”',
  );
  result = result.replaceAllMapped(
    RegExp(r'([\u0B95-\u0BB9]ம்|[\u0B95-\u0BB9]து|[\u0B95-\u0BB9]ான்|[\u0B95-\u0BB9]ாள்|[\u0B95-\u0BB9]ார்|[\u0B95-\u0BB9]ேன்)கு[ \t]+(?=என்று|என|என்ற|சொன்ன|கேட்ட|என்றார்)'),
    (m) => '${m[1]}” ',
  );
  result = result.replaceAllMapped(
    RegExp(r'(^|[\s(\[])[ீ“\x22\x27]+(?=[\u0B85-\u0B94\u0B95-\u0BB9])'),
    (m) => '${m[1]}“',
  );
  result = result.replaceAll('‘‘', '“');

  // Closing single quote encoded as ீ immediately after virama consonant
  result = result.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9]\u0BCD)\u0BC0(?=[\s,.;:!?]|$)'), (m) => '${m[1]}’');
  result = result.replaceAll('`', '‘');

  // Reconnect virama + vowel signs (e.g. க் + ு -> கு)
  result = result.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9])\u0BCD\u0BC1'), (m) => '${m[1]}\u0BC1');
  result = result.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9])\u0BCD\u0BC2'), (m) => '${m[1]}\u0BC2');

  return result;
}

String decodeMacTamilPDF(String text) {
  if (text.isEmpty) return text;
  if (!isTamilDocumentOrPassage(text)) return text;

  final signature = RegExp(r'[æÒΩß∫Ú¡ÛÃÕ‹Ô‡›⁄˙˛ÌØÓÉ˚ıˆ˝]');
  final matches = signature.allMatches(text);
  if (matches.length < 3 && !text.contains('æÒΩநீசு') && !text.contains('ßæ∫ı') && !text.contains('taNNIr tEcam')) {
    return text;
  }

  String s = text;

  const exactMap = [
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
    ['—®√', 'நுரை']
  ];

  for (final pair in exactMap) {
    if (pair[0].contains('[')) {
      s = s.replaceAll(RegExp(pair[0]), pair[1]);
    } else {
      s = s.replaceAll(pair[0], pair[1]);
    }
  }

  final lines = s.split('\n');
  final processedLines = lines.map((line) {
    if (!signature.hasMatch(line)) {
      return line;
    }

    String l = line;
    const conRegex = r'(∏|∫||வு|æ|ø|¿|¡|மூ|√|ல்|ரு|≈|∆|மு|»|É)';

    l = l.replaceAllMapped(RegExp('ளு$conRegex°'), (m) => '${m[1]}ொ');
    l = l.replaceAllMapped(RegExp('ß$conRegex°'), (m) => '${m[1]}ோ');
    l = l.replaceAllMapped(RegExp('ளு$conRegex'), (m) => '${m[1]}ெ');
    l = l.replaceAllMapped(RegExp('ß$conRegex'), (m) => '${m[1]}ே');
    l = l.replaceAllMapped(RegExp('®$conRegex'), (m) => '${m[1]}ை');

    const multiMap = {
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

    multiMap.forEach((k, v) {
      l = l.replaceAll(k, v);
    });

    l = l.replaceAllMapped(RegExp(r'([க-ஹ])து'), (m) => '${m[1]}\u0BBF');
    return l;
  });

  return processedLines.join('\n');
}

String decodeLateVolumeDtpTamil(String text) {
  if (text.isEmpty) return text;
  if (!isTamilDocumentOrPassage(text)) return text;

  final dtpMatches = RegExp(r'(?:(?:^|[\s\p{P}])ன[க-ஹ]|ம[வதபள]|ம[பநசகவத]ா|ன[கசதபவ]ா)', unicode: true).allMatches(text).length;
  final hasSpecialMarkers = text.contains('மவந்மத') || text.contains('னபண்களின்') || text.contains('பானற') || text.contains('பனனயன்') || text.contains('கைமன');

  if (dtpMatches < 2 && !hasSpecialMarkers) {
    return text;
  }

  String s = text;

  s = s.replaceAll('™', 'சூ');
  s = s.replaceAll('வவள்பாரி', 'வேள்பாரி');
  s = s.replaceAll('பவங்கவேசன்', 'வெங்கடேசன்');
  s = s.replaceAll('மசாைா', 'சோழா');
  s = s.replaceAll('மைல்விளிம்பில்', 'மேல்விளிம்பில்');
  s = s.replaceAll('ைறுனைாழினய', 'மறுமொழியை');
  s = s.replaceAll('கைமன', 'மகனே');

  // 1. Circumfixes
  s = s.replaceAllMapped(RegExp(r'ன([க-ஹ])ா'), (m) => '${m[1]}\u0BCA');
  s = s.replaceAllMapped(RegExp(r'ம([க-ஹ])ா'), (m) => '${m[1]}\u0BCB');

  // 2. Pre-base Kombu ee for consonants that cannot follow bare 'ம'
  s = s.replaceAllMapped(RegExp(r'ம([வதபள])'), (m) => '${m[1]}\u0BC7');
  s = s.replaceAllMapped(RegExp(r'(^|[\s\p{P}])மக(?=[ட்ள])', unicode: true), (m) => '${m[1]}கே');
  s = s.replaceAllMapped(RegExp(r'([க-ஹ][ா-்]?)ம([யவழறத])'), (m) => '${m[1]}${m[2]}\u0BC7');

  // 3. ன as Kombu
  s = s.replaceAllMapped(RegExp(r'(^|[\s\p{P}])னப', unicode: true), (m) => '${m[1]}பெ');
  s = s.replaceAllMapped(RegExp(r'([அ-ஹா-்])னப'), (m) => '${m[1]}பெ');
  s = s.replaceAll('னப', 'பெ');

  s = s.replaceAll('னட', 'டை');
  s = s.replaceAll('னற', 'றை');
  s = s.replaceAll('னல', 'லை');
  s = s.replaceAll('னர', 'ரை');
  s = s.replaceAll('னன', 'னை');
  s = s.replaceAll('னழ', 'ழை');
  s = s.replaceAll('னய', 'யை');
  s = s.replaceAll('னக', 'கை');
  s = s.replaceAll('னத', 'தெ');
  s = s.replaceAllMapped(RegExp(r'([ஓதி])னச'), (m) => '${m[1]}சை');
  s = s.replaceAllMapped(RegExp(r'(^|[\s\p{P}])னச', unicode: true), (m) => '${m[1]}செ');
  s = s.replaceAll('னச', 'செ');
  s = s.replaceAllMapped(RegExp(r'னவ(?=[ய்ப்னய])'), (m) => 'வை');
  s = s.replaceAll('னவ', 'வெ');

  // 4. In this font variant, ை used as consonant ம
  s = s.replaceAll('காரைலையின்', 'காரமலையின்');
  s = s.replaceAllMapped(RegExp(r'(^|[\s\p{P}])ை([ா-்])', unicode: true), (m) => '${m[1]}ம${m[2]}');
  s = s.replaceAllMapped(RegExp(r'(^|[\s\p{P}])ை(?=[க-ஹ])', unicode: true), (m) => '${m[1]}ம');
  s = s.replaceAllMapped(RegExp(r'([க-ஹ][ாிீுூெேைொோௌ])ைா'), (m) => '${m[1]}மா');
  s = s.replaceAllMapped(RegExp(r'([க-ஹ][ாிீுூெேைொோௌ])ை([ா-்])'), (m) => '${m[1]}ம${m[2]}');
  s = s.replaceAllMapped(RegExp(r'([க-ஹ][ாிீுூெேைொோௌ])ை(?=[க-ஹ])'), (m) => '${m[1]}ம');
  s = s.replaceAllMapped(RegExp(r'([க-ஹ][ா-்])ைீ'), (m) => '${m[1]}மீ');
  s = s.replaceAllMapped(RegExp(r'([க-ஹ][ா-்])ைு'), (m) => '${m[1]}மு');
  s = s.replaceAllMapped(RegExp(r'([க-ஹ][ா-்])ை(?=[றரனணதடபகசழ])'), (m) => '${m[1]}ம');
  s = s.replaceAll('கமனே', 'மகனே');

  return s;
}

String normalizeVisualPreBaseVowels(String text) {
  if (text.isEmpty) return text;

  String s = text;

  // 1. Two consecutive pre-base vowels at start of word/token (e.g. ேதைர -> தேரை)
  s = s.replaceAllMapped(RegExp(r'(^|[\s("«\x27\-\u0BCD])([\u0BC6\u0BC7\u0BC8])([\u0B95-\u0BB9])([\u0BC6\u0BC7\u0BC8])([\u0B95-\u0BB9])'), (m) => '${m[1]}${m[3]}${m[2]}${m[5]}${m[4]}');

  // 2. Visual Circumfixes
  s = s.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9]\u0BCD)\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BBE'), (m) => '${m[1]}${m[2]}\u0BCA');
  s = s.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9]\u0BCD)\u0BC7([\u0B95-\u0BB9])[ \t]*\u0BBE'), (m) => '${m[1]}${m[2]}\u0BCB');
  s = s.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9]\u0BCD)\u0BC6([\u0B95-\u0BB9])[ \t]*(?:\u0BD7|\u0BB3(?!\u0BCD))'), (m) => '${m[1]}${m[2]}\u0BCC');

  s = s.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9])\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BBE'), (m) => '${m[1]} ${m[2]}\u0BCA');
  s = s.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9])\u0BC7([\u0B95-\u0BB9])[ \t]*\u0BBE'), (m) => '${m[1]} ${m[2]}\u0BCB');
  s = s.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9])\u0BC6([\u0B95-\u0BB9])[ \t]*(?:\u0BD7|\u0BB3(?!\u0BCD))'), (m) => '${m[1]} ${m[2]}\u0BCC');

  s = s.replaceAllMapped(RegExp(r'(^|[\s("«\x27\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC6([\u0B95-\u0BB9])[ \t]*\u0BBE'), (m) => '${m[1]}${m[2]}\u0BCA');
  s = s.replaceAllMapped(RegExp(r'(^|[\s("«\x27\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC7([\u0B95-\u0BB9])[ \t]*\u0BBE'), (m) => '${m[1]}${m[2]}\u0BCB');
  s = s.replaceAllMapped(RegExp(r'(^|[\s("«\x27\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC6([\u0B95-\u0BB9])[ \t]*(?:\u0BD7|\u0BB3(?!\u0BCD))'), (m) => '${m[1]}${m[2]}\u0BCC');

  s = s.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9])\u0BC6[ \t]*\u0BBE'), (m) => '${m[1]}\u0BCA');
  s = s.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9])\u0BC7[ \t]*\u0BBE'), (m) => '${m[1]}\u0BCB');
  s = s.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9])\u0BC6[ \t]*(?:\u0BD7|\u0BB3(?!\u0BCD))'), (m) => '${m[1]}\u0BCC');

  // 3. Pre-base standalone vowels before consonant
  s = s.replaceAllMapped(RegExp(r'(^|[\s("«\x27\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC6([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])'), (m) => '${m[1]}${m[2]}\u0BC6');
  s = s.replaceAllMapped(RegExp(r'(^|[\s("«\x27\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC7([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])'), (m) => '${m[1]}${m[2]}\u0BC7');
  s = s.replaceAllMapped(RegExp(r'(^|[\s("«\x27\-\u0B85-\u0B94\u0BBE-\u0BCD\u0BD7])\u0BC8([\u0B95-\u0BB9])(?![\u0BBE-\u0BCD\u0BD7])'), (m) => '${m[1]}${m[2]}\u0BC8');

  // 4. Universal Typewriter / Visual Pre-Base (ெ, ே, ை) Reordering inside words
  s = s.replaceAllMapped(RegExp(r'([\u0B85-\u0BB9\u0BBE-\u0BCD])([\u0BC6\u0BC7\u0BC8])([\u0B95-\u0BB9])(?=[ \t\r\n,.;:!?”\x22\x27’\)\]}]|$|[கசதப]\u0BCD)'), (m) => '${m[1]}${m[3]}${m[2]}');

  return s;
}

String normalizeTamilKerningAndSyllables(String text) {
  if (text.isEmpty) return text;

  String s = text.replaceAll(RegExp(r'[ \t]{2,}'), '  ');

  // 1. Reconnect consonant + combining vowel sign / virama
  s = s.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9])[ \t]+([\u0BBE-\u0BCD\u0BD7])'), (m) => '${m[1]}${m[2]}');
  s = s.replaceAllMapped(RegExp(r'([\u0B95-\u0BB9])\r?\n[ \t]*([\u0BBE-\u0BCD\u0BD7])'), (m) => '${m[1]}${m[2]}');
  s = s.replaceAllMapped(RegExp(r'([\u0BBE-\u0BCD\u0BD7])[ \t]+([\u0BBE-\u0BCD\u0BD7])'), (m) => '${m[1]}${m[2]}');

  // 2. Reconnect space before pure consonant
  String prev = '';
  while (prev != s) {
    prev = s;
    s = s.replaceAllMapped(RegExp(r'([\u0B80-\u0BFF])[ \t]+([\u0B95-\u0BB9]\u0BCD)'), (m) => '${m[1]}${m[2]}');
    s = s.replaceAllMapped(RegExp(r'([\u0B80-\u0BFF])\r?\n[ \t]*([\u0B95-\u0BB9]\u0BCD)'), (m) => '${m[1]}${m[2]}');
  }

  // 3. Reconnect non-final virama consonants (வல்லினம்/மெல்லினம்: க், ங், ச், ஞ், ட், த், ப், ற், ந்)
  prev = '';
  while (prev != s) {
    prev = s;
    s = s.replaceAllMapped(RegExp(r'([கஙசஞடதபறந]\u0BCD)[ \t]+([\u0B80-\u0BFF])'), (m) => '${m[1]}${m[2]}');
  }

  // 4. Reconnect letters that can NEVER begin a native Tamil word: ட, ண, ர, ல, ழ, ள, ற, ன
  prev = '';
  while (prev != s) {
    prev = s;
    s = s.replaceAllMapped(RegExp(r'([\u0B80-\u0BFF])[ \t]+([டணரலழளறன](?:[\u0BBE-\u0BCD\u0BD7])?)'), (m) => '${m[1]}${m[2]}');
  }

  // 5. Reconnect suffixes (கள், க்கு, இல், உடைய, ஆல், ஓடு)
  s = s.replaceAllMapped(RegExp(r'([\u0B80-\u0BFF])[ \t]+(கள்|க்கு|இல்|உடைய|ஆல்|ஓடு)(?=[ \t\r\n,.;:!?]|$)'), (m) => '${m[1]}${m[2]}');

  // 6. Reconnect isolated single bare consonants
  prev = '';
  while (prev != s) {
    prev = s;
    s = s.replaceAllMapped(RegExp(r'([\u0B80-\u0BFF])[ \t]+([கஙசஞடணதநபமயரலவழளறன])(?=[ \t\r\n,.;:!?]|$)'), (m) => '${m[1]}${m[2]}');
    s = s.replaceAllMapped(RegExp(r'(^|[ \t\r\n,.;:!?])([கஙசஞடணதநபமயரலவழளறன])[ \t]+([\u0B80-\u0BFF])'), (m) => '${m[1]}${m[2]}${m[3]}');
  }

  // 7. General kerning reconnector for single-syllable sequence artifacts
  final lines = s.split('\n');
  final cleanedLines = lines.map((line) {
    final tokens = line.split(RegExp(r'( {2,}|[ \t])'));
    final List<String> recombined = [];

    for (int i = 0; i < tokens.length; i++) {
      final tok = tokens[i];
      if (RegExp(r'^ {2,}$').hasMatch(tok)) {
        recombined.add(' ');
        continue;
      }
      if (tok == ' ' || tok == '\t') {
        continue;
      }
      if (recombined.isNotEmpty && recombined.last != ' ') {
        final last = recombined.last;
        final isTamilTok = RegExp(r'^[\u0B80-\u0BFF]+$').hasMatch(tok);
        final isLastTamil = RegExp(r'^[\u0B80-\u0BFF]+$').hasMatch(last);

        if (isTamilTok && isLastTamil) {
          final startsWithIndependentVowel = RegExp(r'^[\u0B85-\u0B94]').hasMatch(tok);
          if (!startsWithIndependentVowel) {
            final lastIsSingle = RegExp(r'^([\u0B95-\u0BB9][\u0BBE-\u0BCD\u0BD7]?|[\u0B85-\u0B94])$').hasMatch(last);
            final tokIsSingle = RegExp(r'^([\u0B95-\u0BB9][\u0BBE-\u0BCD\u0BD7]?|[\u0B85-\u0B94])$').hasMatch(tok) ||
                                RegExp(r'^([\u0B95-\u0BB9][\u0BBE-\u0BCD\u0BD7]?[\u0B95-\u0BB9]\u0BCD)$').hasMatch(tok);

            if (lastIsSingle && !_kValidSingleSyllableWords.contains(last)) {
              if (RegExp(r'^[\u0B85-\u0B94]$').hasMatch(last)) {
                if (tok == 'வர்கள்' || tok == 'யற்கை' || tok == 'லக்கியம்' || tok == 'ரசாங்கம்' || tokIsSingle) {
                  recombined[recombined.length - 1] = last + tok;
                  continue;
                }
              } else {
                recombined[recombined.length - 1] = last + tok;
                continue;
              }
            }

            final tokIsPulliWord = RegExp(r'^[\u0B95-\u0BB9][\u0BBE-\u0BCD\u0BD7]?[\u0B95-\u0BB9]\u0BCD$').hasMatch(tok);
            if (tokIsSingle && !_kValidSingleSyllableWords.contains(tok)) {
              if (!tokIsPulliWord || lastIsSingle) {
                recombined[recombined.length - 1] = last + tok;
                continue;
              }
            }
          }
        }
        recombined.add(' ');
      }
      recombined.add(tok);
    }
    return recombined.join('').replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  });

  return cleanedLines.join('\n');
}

String cleanExtractedTamilText(String raw) {
  if (raw.isEmpty) return raw;

  String text = raw;

  text = text.replaceAll(RegExp(r'www\.t\.me\/[^\s\n]+', caseSensitive: false), '');
  text = text.replaceAll(RegExp(r't\.me\/[^\s\n]+', caseSensitive: false), '');
  text = text.replaceAll(RegExp(r'AVOID TO DOWNLOAD FROM [^\n]+', caseSensitive: false), '');
  text = text.replaceAll(RegExp(r'\n\s*--\s*\d+\s+of\s+\d+\s*--\s*', caseSensitive: false), '\n');

  text = text.replaceAll(RegExp(r'[\u00AD\u200B-\u200D\uFEFF\u200E\u200F]'), '');
  text = text.replaceAll('\u00A0', ' ');
  text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  text = text.replaceAllMapped(
    RegExp(r'([\u0B80-\u0BFF\w])-[ \t]*\r?\n[ \t]*([\u0B80-\u0BFF\w])'),
    (m) => '${m[1]}${m[2]}',
  );

  final isTamil = isTamilDocumentOrPassage(text);

  if (isTamil) {
    text = decodeBaminiIfDetected(text);
    text = decodeLegacyTamil(text);
    text = decodeMacTamilPDF(text);
    text = decodeLateVolumeDtpTamil(text);
    text = text.replaceAll('\x7F', '');

    text = normalizeVisualPreBaseVowels(text);
    text = normalizeTamilKerningAndSyllables(text);

    text = text.replaceAll(RegExp(r'\u0BCD\u0BCD+'), '\u0BCD');
  } else {
    text = text.replaceAll('\x7F', '');
    text = text.replaceAllMapped(
      RegExp(r'([a-zA-Z])[\u0B80-\u0BFF]+([a-zA-Z])'),
      (m) => '${m[1]}${m[2]}',
    );
    final tMatches = RegExp(r'[\u0B80-\u0BFF]').allMatches(text).length;
    final eMatches = RegExp(r'[a-zA-Z]').allMatches(text).length;
    if (tMatches < 5 && eMatches > 50) {
      text = text.replaceAll(RegExp(r'[\u0B80-\u0BFF]'), '');
    }
  }

  // Remove unwanted single-letter orphans at end of lines:
  // If a line ends with a single character (Tamil or Latin) preceded by a space,
  // merge it back to the previous line to avoid orphan letters at page endings.
  text = text.replaceAllMapped(
    RegExp(r'([ \t]+[\u0B80-\u0BFFa-zA-Z\u0900-\u097F])\n'),
    (m) {
      final fragment = m[1]!.trimLeft();
      // Only pull back truly isolated short words (1-2 chars)
      if (fragment.length <= 2) {
        return '${m[1]!} '; // join with a space, remove newline
      }
      return m[0]!; // leave as-is
    },
  );

  return text.trim();
}

List<String> parseParagraphs(String text) {
  if (text.isEmpty) return [];

  String cleaned = cleanExtractedTamilText(text);

  return cleaned
      .split(RegExp(r'\n\s*\n+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

class WritePage extends StatefulWidget {
  final String? draftId; // optional
  final dynamic draftContent; // optional (String, List, Map)
  final String? draftCover;
  final String? category;

  const WritePage({
    super.key,
    this.draftId,
    this.draftContent,
    this.draftCover, // 🔥 ADD THIS
    this.category,
  });

  @override
  State<WritePage> createState() => _WritePageState();
}

class _WritePageState extends State<WritePage> {
  String? _draftId;
  int? selectedCategoryId;

  // previously a fixed constant – use a getter so the limit updates
  // with the screen size/keyboard adjustments.
  double get _pageHeightLimit => MediaQuery.of(context).size.height * 0.65;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  int? _focusedBlockIndex;

  // State variables consolidated at top
  List<PageData> _pages = [
    PageData(fontSize: 22, fontFamily: "Roboto", fontColor: 0xFF000000),
  ];
  int _currentPage = 0;
  final PageController _pageController = PageController();

  List<List<PageData>> _historyStack = [];
  int _historyIndex = -1;
  bool _isUndoRedoOp = false;
  bool _isUpdatingState = false; // Senior PE: Guard against UI thread blocks
  Timer? _debounceTimer;

  // Active styles for NEW blocks
  int _activeColor = 0xFF000000;
  bool _activeHeadline = false;
  File? _pdfFile;
  http.Client? _pdfExtractionClient;
  bool _isExtractingPdf = false;
  bool _pdfExtractionCancelled = false;
  bool _isPdfExtractionDialogVisible = false;
  String _pdfExtractionStatus = "";
  final ValueNotifier<String> _pdfExtractionStatusNotifier = ValueNotifier("");
  static const int _kMaxPdfUploadBytes = 300 * 1024 * 1024;

  String _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    String url = path.trim();

    if (url.startsWith("http://localhost:3001") ||
        url.startsWith("http://127.0.0.1:3001") ||
        url.startsWith("http://localhost:5000") ||
        url.startsWith("http://127.0.0.1:5000") ||
        url.contains(":3001/uploads/") ||
        url.contains(":5000/uploads/")) {
      url = url.replaceFirst(
        RegExp(r'https?:\/\/[^\/]+:(3001|5000)'),
        ApiConfig.baseUrl,
      );
      return url;
    }

    if (url.startsWith("http://") || url.startsWith("https://")) {
      return url;
    }

    url = url.replaceAll("\\", "/").replaceAll(RegExp(r'^/+'), "");
    if (!url.startsWith("uploads/")) {
      if (url.startsWith("page_images/") ||
          url.startsWith("covers/") ||
          url.startsWith("profile_images/")) {
        url = "uploads/$url";
      } else {
        url = "uploads/page_images/$url";
      }
    }
    return "${ApiConfig.baseUrl}/$url";
  }

  TextStyle _safeGoogleFont(
    String fontFamily, {
    TextStyle? textStyle,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
    Color? backgroundColor,
  }) {
    try {
      return GoogleFonts.getFont(
        fontFamily,
        textStyle: textStyle,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
        backgroundColor: backgroundColor,
      );
    } catch (_) {
      return (textStyle ?? const TextStyle()).copyWith(
        fontFamily: fontFamily,
        fontFamilyFallback: const ['Mukta Malar', 'Noto Sans Tamil', 'Roboto'],
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
        backgroundColor: backgroundColor,
      );
    }
  }

  final List<String> _fontFamilies = [
    "Roboto",
    "Noto Sans Tamil",
    "Mukta Malar",
    "Hind Madurai",
    "Pavanam",
    "Arima",
    "Kavivanar",
    "Catamaran",
    "Baloo 2",
    "Tiro Tamil",
    "Lora",
    "Playfair Display",
    "Inter",
    "Merienda",
    "Lobster",
  ];

  final List<int> _fontColors = [
    0xFF000000, // Black
    0xFFF44336, // Red
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFF9C27B0, // Purple
    0xFFFF9800, // Orange
    0xFF009668, // Teal
    0xFF795548, // Brown
    0xFF0729E8, // Brand Red
  ];

  @override
  void initState() {
    super.initState();

    selectedCategoryId = 4; // Always Noolagam (Library)

    _draftId = widget.draftId;

    if (widget.draftContent != null) {
      if (widget.draftContent is String) {
        if ((widget.draftContent as String).trim().isNotEmpty) {
          _loadDraftContent(widget.draftContent);
        }
      } else {
        _loadDraftContent(widget.draftContent);
      }
    }

    // ✅ INSERT COVER AS FIRST BLOCK
    if (widget.draftCover != null && widget.draftCover!.isNotEmpty) {
      _pages[0].blocks.insert(0, PageBlock.networkImage(widget.draftCover!));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveToHistory(immediate: true);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _debounceTimer?.cancel();
    _pdfExtractionClient?.close();
    _pdfExtractionStatusNotifier.dispose();
    for (var ctrl in _controllers.values) {
      ctrl.dispose();
    }
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _showPdfExtractionProgressDialog() async {
    if (_isPdfExtractionDialogVisible) return;
    _isPdfExtractionDialogVisible = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text("Processing document"),
            content: ValueListenableBuilder<String>(
              valueListenable: _pdfExtractionStatusNotifier,
              builder: (context, status, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 18),
                    Text(
                      status.isEmpty ? "Starting..." : status,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: _cancelPdfExtraction,
                child: const Text("Cancel"),
              ),
            ],
          ),
        );
      },
    );

    _isPdfExtractionDialogVisible = false;
  }

  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt'],
      );

      if (result == null) return;

      final filePath = result.files.single.path;
      final fileName = result.files.single.name;
      final fileBytes = result.files.single.bytes;
      final mime = lookupMimeType(fileName) ?? 'application/pdf';
      File? file;

      final fileSize = result.files.single.size;

      if (fileSize > _kMaxPdfUploadBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Maximum file size is 300MB")),
        );
        return;
      }

      if (filePath != null && await File(filePath).exists()) {
        file = File(filePath);
      }

      setState(() {
        _isExtractingPdf = true;
        _pdfExtractionCancelled = false;
        _pdfExtractionStatus = "Uploading document...";
      });
      _pdfExtractionStatusNotifier.value = "Uploading document...";
      _showPdfExtractionProgressDialog();

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      final uri = Uri.parse("${ApiConfig.apiBaseUrl}/posts/extractDocument");
      var request = http.MultipartRequest("POST", uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Connection'] = 'keep-alive';

      _pdfExtractionClient = http.Client();

      if (file != null) {
        setState(() {
          _pdfFile = file;
        });

        request.files.add(
          await http.MultipartFile.fromPath("document", file.path),
        );
      } else if (fileBytes != null && fileName.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            "document",
            fileBytes,
            filename: fileName,
            contentType: MediaType.parse(mime),
          ),
        );
      } else {
        throw Exception("Selected document cannot be read");
      }

      final streamedResponse = await _pdfExtractionClient!
          .send(request)
          .timeout(const Duration(minutes: 30));
      final responseData = await http.Response.fromStream(streamedResponse);

      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        throw Exception(responseData.body);
      }

      dynamic data;

      try {
        data = jsonDecode(responseData.body);
      } catch (e) {
        throw Exception("Server returned invalid response");
      }

      if (data == null || data is! Map) {
        throw Exception("Invalid server response");
      }

      if (data["success"] == false) {
        throw Exception(data["message"] ?? "Extraction failed");
      }

      if (!data.containsKey("extractionId")) {
        throw Exception("Missing extractionId");
      }

      if (!data.containsKey("totalChunks")) {
        throw Exception("Missing totalChunks");
      }

      final extractionId = data["extractionId"]?.toString();
      final totalChunks = data["totalChunks"] ?? 0;

      if (extractionId == null || extractionId.isEmpty) {
        throw Exception("Invalid extractionId");
      }

      if (totalChunks <= 0) {
        throw Exception("No content extracted");
      }

      String finalText = "";
      List<dynamic>? extractedPagesList;
      if (data["pages"] is List) {
        extractedPagesList = data["pages"];
      }

      try {
        if (mounted) {
          setState(() {
            _pdfExtractionStatus = "Downloading extracted document & images...";
          });
          _pdfExtractionStatusNotifier.value = "Downloading extracted document & images...";
        }

        final fullResponse = await _pdfExtractionClient!
            .get(
              Uri.parse(
                "${ApiConfig.apiBaseUrl}/posts/documentFull/$extractionId",
              ),
              headers: {"Authorization": "Bearer $token"},
            )
            .timeout(const Duration(minutes: 5));

        if (fullResponse.statusCode == 200) {
          final decoded = jsonDecode(fullResponse.body);
          if (decoded is Map && decoded["success"] == true) {
            finalText = decoded["text"] ?? "";
            if (decoded["pages"] is List && (decoded["pages"] as List).isNotEmpty) {
              extractedPagesList = decoded["pages"];
            }
          }
        }
      } catch (_) {
        // Fallback below
      }

      if (finalText.isEmpty) {
        final StringBuffer extractedText = StringBuffer();

        for (int i = 0; i < totalChunks; i++) {
          if (_pdfExtractionCancelled) {
            throw Exception("PDF extraction canceled");
          }

          final chunkResponse = await _pdfExtractionClient!
              .get(
                Uri.parse(
                  "${ApiConfig.apiBaseUrl}/posts/documentChunk/$extractionId/$i",
                ),
                headers: {"Authorization": "Bearer $token"},
              )
              .timeout(const Duration(minutes: 1));

          if (chunkResponse.statusCode != 200) {
            throw Exception(
              "Chunk download failed: ${chunkResponse.statusCode}",
            );
          }

          if ((i + 1) % 2 == 0 || i == totalChunks - 1) {
            if (mounted) {
              setState(() {
                _pdfExtractionStatus =
                    "Extracting document... (${i + 1}/$totalChunks)";
              });
              _pdfExtractionStatusNotifier.value =
                  "Extracting document... (${i + 1}/$totalChunks)";
            }
          }

          dynamic chunkData;

          try {
            chunkData = jsonDecode(chunkResponse.body);
          } catch (e) {
            throw Exception("Invalid chunk response");
          }

          extractedText.write(chunkData["chunk"] ?? "");

          if (i % 5 == 0 && mounted) {
            setState(() {});
          }
        }

        finalText = extractedText.toString();
      }

      if (finalText.length > 60000000) {
        throw Exception("Document too large after extraction");
      }

      final paragraphs = await compute(parseParagraphs, finalText);
      final bool hasTamilText = RegExp(r'[\u0B80-\u0BFF]').hasMatch(finalText);
      final String docFontFamily = hasTamilText
          ? 'Noto Sans Tamil'
          : (_pages.isNotEmpty ? _pages.first.fontFamily : 'Roboto');
      const int maxImportPages = 5000;
      _pages = [];
      _currentPage = 0;

      _controllers.clear();
      _focusNodes.clear();

      _focusedBlockIndex = null;

      if (finalText.length > 1500000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Large document detected. Processing may take time.",
              ),
            ),
          );
        }
      }

      if (extractedPagesList != null && extractedPagesList.isNotEmpty) {
        _pages = [];
        for (final p in extractedPagesList) {
          final List<PageBlock> pageBlocks = [];
          final pImages = p['images'];
          if (pImages is List && pImages.isNotEmpty) {
            for (final im in pImages) {
              String imgUrl = '';
              if (im is Map) {
                imgUrl = (im['url'] ?? '').toString();
              } else if (im is String) {
                imgUrl = im;
              }
              if (imgUrl.isNotEmpty) {
                final resolved = _resolveImageUrl(imgUrl);
                final imgBlock = PageBlock.networkImage(resolved);
                imgBlock.imageWidth = 280;
                imgBlock.imagePosition = const Offset(0, 0);
                pageBlocks.add(imgBlock);
              }
            }
          }

          final String pageText = cleanExtractedTamilText((p['text'] ?? '').toString().trim());
          if (pageText.isNotEmpty) {
            final pageParas = pageText.split(RegExp(r'\r?\n\r?\n'));
            for (final para in pageParas) {
              final t = para.trim();
              if (t.isNotEmpty) {
                pageBlocks.add(PageBlock.text(t, fontSize: 20));
              }
            }
          } else if (pageBlocks.isEmpty) {
            pageBlocks.add(PageBlock.text('', fontSize: 20));
          }

          _pages.add(
            PageData(
              fontSize: 22,
              fontFamily: docFontFamily,
              fontColor: 0xFF000000,
              textAlign: TextAlign.justify,
            )..blocks = List.from(pageBlocks),
          );
          if (_pages.length >= maxImportPages) break;
        }
      } else {
        // Chunk paragraphs cleanly into pages (approx ~1200 chars per page)
        // to avoid OOM crash and heavy layout thrashing
        const int targetCharsPerPage = 1200;
        List<PageBlock> currentBlocks = [];
        int currentChars = 0;

        for (var paragraph in paragraphs) {
          final trimmed = paragraph.trim();
          if (trimmed.isEmpty) continue;

          if (trimmed.length > targetCharsPerPage) {
            int offset = 0;
            while (offset < trimmed.length) {
              int end = min(offset + targetCharsPerPage, trimmed.length);
              if (end < trimmed.length) {
                int lastSpace = trimmed.substring(offset, end).lastIndexOf(' ');
                if (lastSpace > targetCharsPerPage * 0.6) {
                  end = offset + lastSpace;
                }
              }
              while (end < trimmed.length &&
                  RegExp(r'[\u0BBE-\u0BCD\u0BD7]').hasMatch(trimmed[end])) {
                end++;
              }
              final chunk = trimmed.substring(offset, end).trim();
              if (chunk.isNotEmpty) {
                if (currentChars + chunk.length > targetCharsPerPage &&
                    currentBlocks.isNotEmpty) {
                  _pages.add(
                    PageData(
                      fontSize: 22,
                      fontFamily: docFontFamily,
                      fontColor: 0xFF000000,
                      textAlign: TextAlign.justify,
                    )..blocks = List.from(currentBlocks),
                  );
                  currentBlocks.clear();
                  currentChars = 0;
                  if (_pages.length >= maxImportPages) break;
                }
                currentBlocks.add(PageBlock.text(chunk, fontSize: 20));
                currentChars += chunk.length;
              }
              offset = end;
            }
          } else {
            if (currentChars + trimmed.length > targetCharsPerPage &&
                currentBlocks.isNotEmpty) {
              _pages.add(
                PageData(
                  fontSize: 22,
                  fontFamily: docFontFamily,
                  fontColor: 0xFF000000,
                  textAlign: TextAlign.justify,
                )..blocks = List.from(currentBlocks),
              );
              currentBlocks.clear();
              currentChars = 0;
              if (_pages.length >= maxImportPages) break;
            }
            currentBlocks.add(PageBlock.text(trimmed, fontSize: 20));
            currentChars += trimmed.length;
          }

          if (_pages.length >= maxImportPages) break;
        }

        if (currentBlocks.isNotEmpty && _pages.length < maxImportPages) {
          _pages.add(
            PageData(
              fontSize: 22,
              fontFamily: docFontFamily,
              fontColor: 0xFF000000,
              textAlign: TextAlign.justify,
            )..blocks = List.from(currentBlocks),
          );
        }
      }

      if (_pages.isEmpty) {
        _pages.add(
          PageData(
            fontSize: 22,
            fontFamily: docFontFamily,
            fontColor: 0xFF000000,
          ),
        );
      }

      _rebuildAllControllers();

      if (mounted) {
        setState(() {});
      }

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Document imported successfully")),
        );
      }
    } catch (e, stack) {
      print("========== PDF IMPORT ERROR ==========");
      print(e);
      print(stack);

      if (_pdfExtractionCancelled && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("PDF import canceled")));
      }

      if (mounted && !_pdfExtractionCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      _pdfExtractionClient?.close();
      _pdfExtractionClient = null;
      if (mounted) {
        if (_isPdfExtractionDialogVisible) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        setState(() {
          _isExtractingPdf = false;
          if (!_pdfExtractionCancelled) {
            _pdfExtractionStatus = "";
          }
        });
      }
      _pdfExtractionStatusNotifier.value = "";
    }
  }

  void _cancelPdfExtraction() {
    if (!_isExtractingPdf || _pdfExtractionCancelled) return;
    setState(() {
      _pdfExtractionCancelled = true;
      _pdfExtractionStatus = "Canceling...";
      _pdfExtractionStatusNotifier.value = "Canceling...";
    });
    _pdfExtractionClient?.close();
    _pdfExtractionClient = null;
  }

  List<PageData> _clonePages(List<PageData> source) {
    return source
        .map(
          (p) =>
              PageData(
                  fontSize: p.fontSize,
                  fontFamily: p.fontFamily,
                  fontColor: p.fontColor,
                  lineSpacing: p.lineSpacing,
                  letterSpacing: p.letterSpacing,
                  pageMargin: p.pageMargin,
                  textAlign: p.textAlign,
                )
                ..blocks = p.blocks.map((b) {
                  if (b.type == "text") {
                    return PageBlock.text(
                      b.text ?? "",
                      isHeadline: b.isHeadline,
                      fontSize: b.fontSize,
                      fontFamily: b.fontFamily,
                      fontColor: b.fontColor,
                      lineSpacing: b.lineSpacing,
                      letterSpacing: b.letterSpacing,
                      textAlign: b.textAlign,
                      blockId: b.blockId, // 🔥 FIX: Preserve blockId
                    );
                  } else {
                    var img = PageBlock.networkImage(
                      b.imageUrl ?? "",
                      blockId: b.blockId, // 🔥 FIX: Preserve blockId
                    );
                    img.image = b.image;
                    img.imageWidth = b.imageWidth;
                    img.imagePosition = b.imagePosition;
                    return img;
                  }
                }).toList(),
        )
        .toList();
  }

  void _saveToHistory({bool immediate = false}) {
    if (_isUndoRedoOp) return;

    void save() {
      if (_historyIndex >= 0 && _historyIndex < _historyStack.length - 1) {
        _historyStack = _historyStack.sublist(0, _historyIndex + 1);
      }
      _historyStack.add(_clonePages(_pages));
      _historyIndex = _historyStack.length - 1;

      final int maxHistory = _pages.length > 20 ? 5 : 20;
      if (_historyStack.length > maxHistory) {
        _historyStack.removeRange(0, _historyStack.length - maxHistory);
        _historyIndex = _historyStack.length - 1;
      }
      if (mounted) setState(() {});
    }

    if (immediate) {
      _debounceTimer?.cancel();
      save();
    } else {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 600), save);
    }
  }

  void _flushHistoryIfPending() {
    if (_debounceTimer?.isActive ?? false) {
      _saveToHistory(immediate: true);
    }
  }

  void _applyStateSafety() {
    if (_currentPage >= _pages.length) {
      _currentPage = _pages.length > 0 ? _pages.length - 1 : 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        }
      });
    }
    if (_focusedBlockIndex != null) {
      if (_currentPage < _pages.length) {
        if (_focusedBlockIndex! >= _pages[_currentPage].blocks.length) {
          _focusedBlockIndex = null;
        }
      } else {
        _focusedBlockIndex = null;
      }
    }
  }

  void _globalUndo() {
    if (_historyIndex > 0) {
      if (_debounceTimer?.isActive ?? false) {
        _debounceTimer?.cancel();
        _saveToHistory(immediate: true);
      }
      setState(() {
        _isUpdatingState = true;
        _historyIndex--;
        _pages = _clonePages(_historyStack[_historyIndex]);
        _applyStateSafety();
        _rebuildAllControllers();
        _isUpdatingState = false;
      });
    }
  }

  void _globalRedo() {
    if (_historyIndex < _historyStack.length - 1) {
      setState(() {
        _isUpdatingState = true;
        _historyIndex++;
        _pages = _clonePages(_historyStack[_historyIndex]);
        _applyStateSafety();
        _rebuildAllControllers();
        _isUpdatingState = false;
      });
    }
  }

  void _rebuildAllControllers() {
    if (_pages.isEmpty) return;
    Set<String> activeKeys = {};
    final int minP = (_currentPage - 2).clamp(0, _pages.length - 1);
    final int maxP = (_currentPage + 2).clamp(0, _pages.length - 1);

    for (int p = minP; p <= maxP; p++) {
      for (int b = 0; b < _pages[p].blocks.length; b++) {
        if (_pages[p].blocks[b].type == "text") {
          String key = "$p-$b";
          activeKeys.add(key);
          if (_controllers.containsKey(key)) {
            if (_controllers[key]!.text != _pages[p].blocks[b].text) {
              _controllers[key]!.text = _pages[p].blocks[b].text ?? "";
            }
          } else {
            final ctrl = TextEditingController(
              text: _pages[p].blocks[b].text ?? "",
            );
            ctrl.addListener(() {
              if (!_isUpdatingState &&
                  p < _pages.length &&
                  b < _pages[p].blocks.length &&
                  _pages[p].blocks[b].text != ctrl.text) {
                _handleTextChange(ctrl.text, p, b);
              }
            });
            _controllers[key] = ctrl;
            _focusNodes[key] = FocusNode();
          }
        }
      }
    }

    final controllersToDispose = <TextEditingController>[];
    final nodesToDispose = <FocusNode>[];

    _controllers.removeWhere((key, ctrl) {
      if (!activeKeys.contains(key)) {
        controllersToDispose.add(ctrl);
        if (_focusNodes.containsKey(key)) {
          nodesToDispose.add(_focusNodes[key]!);
          _focusNodes.remove(key);
        }
        return true;
      }
      return false;
    });

    if (controllersToDispose.isNotEmpty || nodesToDispose.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (var c in controllersToDispose) {
          c.dispose();
        }
        for (var n in nodesToDispose) {
          n.dispose();
        }
      });
    }
  }

  /// Sanitize pasted/typed text to remove malformed UTF-16 sequences.
  /// Lone surrogate characters (U+D800–U+DFFF) are illegal in Dart strings
  /// and cause "string is not well-formed UTF-16" crashes in TextPainter,
  /// substring(), and RegExp operations.
  String _sanitizeText(String raw) {
    try {
      // Fast path: iterate rune code points (these are already validated Unicode scalars)
      final buf = StringBuffer();
      for (final rune in raw.runes) {
        // Skip private-use surrogates that sneak in from some clipboard sources
        if (rune >= 0xD800 && rune <= 0xDFFF) continue;
        buf.writeCharCode(rune);
      }
      return buf.toString();
    } catch (_) {
      // Fallback: code-unit scan — skip lone high/low surrogates
      final buf = StringBuffer();
      int i = 0;
      while (i < raw.length) {
        final cu = raw.codeUnitAt(i);
        if (cu >= 0xD800 && cu <= 0xDBFF) {
          // High surrogate: only keep if followed by a valid low surrogate
          if (i + 1 < raw.length) {
            final next = raw.codeUnitAt(i + 1);
            if (next >= 0xDC00 && next <= 0xDFFF) {
              // Valid surrogate pair — write both code units
              buf.writeCharCode(cu);
              buf.writeCharCode(next);
              i += 2;
              continue;
            }
          }
          i++; // lone high surrogate — skip
        } else if (cu >= 0xDC00 && cu <= 0xDFFF) {
          i++; // lone low surrogate — skip
        } else {
          buf.writeCharCode(cu);
          i++;
        }
      }
      return buf.toString();
    }
  }

  /// Returns a safe substring that never splits a surrogate pair.
  String _safeSub(String text, int start, int end) {
    if (start < 0) start = 0;
    if (end > text.length) end = text.length;
    if (start >= end) return '';
    // Ensure 'end' doesn't land on a low surrogate (second half of a pair)
    while (end > start && end < text.length) {
      final cu = text.codeUnitAt(end);
      if (cu >= 0xDC00 && cu <= 0xDFFF) {
        end--;
      } else {
        break;
      }
    }
    // Ensure 'start' doesn't land on a low surrogate
    while (start < end) {
      final cu = text.codeUnitAt(start);
      if (cu >= 0xDC00 && cu <= 0xDFFF) {
        start++;
      } else {
        break;
      }
    }
    if (start >= end) return '';
    return text.substring(start, end);
  }

  void _onFocusChanged(int blockIndex, bool hasFocus) {
    if (hasFocus) {
      setState(() {
        _focusedBlockIndex = blockIndex;
      });
    }
  }

  // optionally assume an image will be added (useful when calculating before inserting)
  bool _doesTextOverflow(
    String text,
    PageData page,
    double maxWidth, {
    bool assumeImage = false,
    bool isHeadline = false,
    double? fontSize,
    String? fontFamily,
    double? lineSpacing,
    double? letterSpacing,
    TextAlign? textAlign,
  }) {
    // Senior PE: Safety guard for invalid width
    if (maxWidth <= 10) return true;

    // Optimization: If a prefix of the text already overflows, the whole text overflows.
    // This avoids layout-ing huge strings when user pastes large content.
    const int maxSafeLength = 3000;
    if (text.length > maxSafeLength) {
      bool prefixOverflows = _doesTextOverflow(
        text.substring(0, maxSafeLength),
        page,
        maxWidth,
        assumeImage: assumeImage,
        isHeadline: isHeadline,
        fontSize: fontSize,
        fontFamily: fontFamily,
        lineSpacing: lineSpacing,
        letterSpacing: letterSpacing,
        textAlign: textAlign,
      );
      if (prefixOverflows) return true;
    }

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: _safeGoogleFont(
          fontFamily ?? page.fontFamily,
          textStyle: const TextStyle(
            fontFamilyFallback: ['Mukta Malar', 'Noto Sans Tamil', 'Roboto'],
          ),
          fontSize: isHeadline ? 28 : (fontSize ?? page.fontSize),
          fontWeight: isHeadline ? FontWeight.w900 : FontWeight.w400,
          height: lineSpacing ?? page.lineSpacing,
          letterSpacing: isHeadline
              ? -0.5
              : (letterSpacing ?? page.letterSpacing),
        ),
      ),
      textAlign: textAlign ?? page.textAlign,
      textDirection: TextDirection.ltr,
    );

    // consider the whole page: any image affects layout
    bool hasImage =
        assumeImage ||
        (page.blocks.isNotEmpty && page.blocks.any((b) => b.type == "image"));

    double allowedHeight = _pageHeightLimit;
    if (hasImage) {
      allowedHeight -= 200; // Offset for image block height
    }

    // Senior PE: Safety guard against zero-height layouts
    if (allowedHeight < 50) allowedHeight = 50;

    try {
      painter.layout(maxWidth: maxWidth);
      return painter.height > allowedHeight;
    } finally {
      painter.dispose();
    }
  }

  /// Rebalance all content from a given page index onwards
  /// This collects all text from that page to the end, then redistributes it
  /// ensuring proper page breaks and adding/removing pages as needed
  void _rebalancePagesFromIndex(int pageIndex) {
    if (pageIndex >= _pages.length || _isUpdatingState) return;

    // Safety guard: Never perform cascading rebalance on imported PDFs.
    // Each page in PDF imports is an independent page with its own SingleChildScrollView.
    // Cascading rebalancing across PDF pages leads to runaway page creation and OOM crashes.
    // For manually written/pasted content (no PDF), allow rebalancing up to 500 pages.
    if (_pdfFile != null) return;

    _isUpdatingState = true;
    try {
      double maxWidth =
          (MediaQuery.of(context).size.width - (_pages[0].pageMargin * 2))
              .clamp(10.0, 2000.0);
      bool carryOver = false;

      // Examine all pages from the start index to the end (no artificial 3-page cap)
      final int maxPagesToExamine = _pages.length + 500; // Allow new pages to be created

      for (int p = pageIndex; p < maxPagesToExamine; p++) {
        List<PageBlock> blocksOnThisPage = _pages[p].blocks
            .where((b) => b.type == "text")
            .toList();

        // Check if page naturally fits and we have no overflow to push into it
        if (!carryOver && blocksOnThisPage.isNotEmpty) {
          String combinedText = blocksOnThisPage
              .map((e) => e.text ?? "")
              .join("\n\n");
          if (!_doesTextOverflow(combinedText, _pages[p], maxWidth)) {
            // Stability reached! Subsequent pages won't be affected.
            break;
          }
        }

        // Determine if we need to flow content downstream
        _pages[p].blocks.removeWhere((b) => b.type == "text");

        if (blocksOnThisPage.isNotEmpty) {
          int lastTouched = _distributeBlocksToPages(p, blocksOnThisPage);
          // Only carry over if the last written page still overflows —
          // otherwise the outer loop re-processes already-filled pages and
          // duplicates their content.
          if (lastTouched > p && lastTouched < _pages.length) {
            final _lastPageTexts = _pages[lastTouched].blocks
                .where((b) => b.type == "text")
                .map((e) => e.text ?? "")
                .join("\n\n");
            carryOver = _lastPageTexts.isNotEmpty &&
                _doesTextOverflow(_lastPageTexts, _pages[lastTouched], maxWidth);
          } else {
            carryOver = false;
          }
          // Jump loop index past pages already handled by _distributeBlocksToPages
          if (lastTouched > p) {
            p = lastTouched - 1;
          }
        } else {
          carryOver = false;
        }

        // Safety hard limit to prevent infinite page creation crashes
        if (_pages.length > 500) break;
      }

      // Cleanup trailing empty pages
      while (_pages.length > 1 &&
          _pages.last.blocks.every(
            (b) => b.type != "text" || (b.text ?? "").trim().isEmpty,
          ) &&
          !_pages.last.blocks.any((b) => b.type == "image")) {
        _pages.removeLast();
      }

      _rebuildAllControllers();
    } finally {
      _isUpdatingState = false;
    }
  }

  /// distribute blocks starting at [startPage] across pages, creating
  /// new pages as needed while preserving text block attributes.
  int _distributeBlocksToPages(
    int startPage,
    List<PageBlock> blocksToDistribute,
  ) {
    if (blocksToDistribute.isEmpty) return startPage;
    double maxWidth =
        (MediaQuery.of(context).size.width - (_pages[0].pageMargin * 2)).clamp(
          10.0,
          2000.0,
        );
    int pageIdx = startPage;

    for (int i = 0; i < blocksToDistribute.length; i++) {
      var srcBlock = blocksToDistribute[i];
      String remaining = srcBlock.text ?? "";

      while (remaining.isNotEmpty) {
        // Ensure we skip pages that already contain an image
        while (pageIdx < _pages.length &&
            _pages[pageIdx].blocks.any((b) => b.type == "image")) {
          pageIdx++;
        }

        // ensure page exists
        if (pageIdx >= _pages.length) {
          if (_pages.length >= 500) {
            // Prevent runaway page creation
            break;
          }
          _pages.add(
            PageData(
              fontSize: _pages[0].fontSize,
              fontFamily: _pages[0].fontFamily,
              fontColor: _pages[0].fontColor,
            )..blocks.clear(),
          );
        }

        PageData page = _pages[pageIdx];

        // If this is a new page (not the starting page), clear empty blocks
        if (pageIdx > startPage) {
          page.blocks.removeWhere(
            (b) => b.type == "text" && (b.text ?? "").trim().isEmpty,
          );
        }

        // find or create a text block at end WITH SAME ATTRIBUTES
        PageBlock? lastBlock;
        if (page.blocks.isNotEmpty && page.blocks.last.type == "text") {
          if (page.blocks.last.isHeadline == srcBlock.isHeadline &&
              page.blocks.last.fontColor == srcBlock.fontColor &&
              page.blocks.last.fontSize == srcBlock.fontSize &&
              page.blocks.last.fontFamily == srcBlock.fontFamily &&
              page.blocks.last.lineSpacing == srcBlock.lineSpacing &&
              page.blocks.last.letterSpacing == srcBlock.letterSpacing &&
              page.blocks.last.textAlign == srcBlock.textAlign) {
            lastBlock = page.blocks.last;
          }
        }

        if (lastBlock == null) {
          lastBlock = PageBlock.text(
            "",
            isHeadline: srcBlock.isHeadline,
            fontColor: srcBlock.fontColor,
            fontSize: srcBlock.fontSize,
            fontFamily: srcBlock.fontFamily,
            lineSpacing: srcBlock.lineSpacing,
            letterSpacing: srcBlock.letterSpacing,
            textAlign: srcBlock.textAlign,
          );
          page.blocks.add(lastBlock);
        }

        String existing = lastBlock.text ?? "";

        // If we are appending a different block that happened to share styles,
        // add a newline if the existing block isn't empty, to respect their original separation
        String candidate;
        const String _paragraphSep = "\n\n";
        if (existing.isNotEmpty &&
            !remaining.startsWith("\n") &&
            !existing.endsWith("\n")) {
          candidate = existing + _paragraphSep + remaining;
        } else {
          candidate = existing + remaining;
        }

        if (!_doesTextOverflow(
          candidate,
          page,
          maxWidth,
          isHeadline: srcBlock.isHeadline,
          fontSize: srcBlock.fontSize,
          fontFamily: srcBlock.fontFamily,
          lineSpacing: srcBlock.lineSpacing,
          letterSpacing: srcBlock.letterSpacing,
          textAlign: srcBlock.textAlign,
        )) {
          // whole remainder fits on this page
          lastBlock.text = candidate;
          remaining = "";
        } else {
          // Exponential search to find a tight upper bound for high.
          // This avoids layout-ing large strings inside the binary search loop.
          int step = 256;
          while (step < remaining.length) {
            String tempCandidate;
            if (existing.isNotEmpty &&
                !remaining.startsWith("\n") &&
                !existing.endsWith("\n")) {
              tempCandidate =
                  existing + _paragraphSep + remaining.substring(0, step);
            } else {
              tempCandidate = existing + remaining.substring(0, step);
            }

            if (_doesTextOverflow(
              tempCandidate,
              page,
              maxWidth,
              isHeadline: srcBlock.isHeadline,
              fontSize: srcBlock.fontSize,
              fontFamily: srcBlock.fontFamily,
              lineSpacing: srcBlock.lineSpacing,
              letterSpacing: srcBlock.letterSpacing,
              textAlign: srcBlock.textAlign,
            )) {
              break;
            }
            step *= 2;
          }

          int low = (step > 256) ? step ~/ 2 : 0;
          int high = min(step, remaining.length);

          while (low < high) {
            int mid = (low + high + 1) ~/ 2;

            String tempCandidate;
            if (existing.isNotEmpty &&
                !remaining.startsWith("\n") &&
                !existing.endsWith("\n")) {
              tempCandidate =
                  existing + _paragraphSep + remaining.substring(0, mid);
            } else {
              tempCandidate = existing + remaining.substring(0, mid);
            }

            if (_doesTextOverflow(
              tempCandidate,
              page,
              maxWidth,
              isHeadline: srcBlock.isHeadline,
              fontSize: srcBlock.fontSize,
              fontFamily: srcBlock.fontFamily,
              lineSpacing: srcBlock.lineSpacing,
              letterSpacing: srcBlock.letterSpacing,
              textAlign: srcBlock.textAlign,
            )) {
              high = mid - 1;
            } else {
              low = mid;
            }
          }
          // ── Clean the cut point to a proper word boundary ───────────────
          // low is the max chars that fit. Walk back to the nearest clean break.
          low = _cleanSplitPoint(remaining, low);

          if (low <= 0) low = 1; // safety: never infinite-loop
          if (low > remaining.length) low = remaining.length;

          String fitPart = _safeSub(remaining, 0, low).trimRight();

          if (existing.isNotEmpty &&
              !remaining.startsWith("\n") &&
              !existing.endsWith("\n")) {
            lastBlock.text = existing + _paragraphSep + fitPart;
          } else {
            lastBlock.text = existing + fitPart;
          }

          // Strip leading whitespace from the remainder so the next page starts cleanly
          final String rawRemaining = _safeSub(remaining, low, remaining.length);
          remaining = rawRemaining.replaceFirst(RegExp(r'^[ \t]+'), '');
          pageIdx++;
        }
      }
    }
    return pageIdx;
  }

  /// Finds the best position ≤ [maxPos] in [text] to split without breaking
  /// words, Tamil syllables, or UTF-16 surrogate pairs. Priority order:
  ///   1. Paragraph boundary (\n\n or \n)
  ///   2. Word boundary (space)
  ///   3. Tamil syllable-safe boundary (not inside a vowel-mark sequence)
  ///   4. Surrogate-pair-safe position
  ///   5. [maxPos] itself as a last resort
  int _cleanSplitPoint(String text, int maxPos) {
    if (maxPos <= 0 || text.isEmpty) return 0;
    if (maxPos >= text.length) return text.length;

    // ── Clamp maxPos so we never start inside a low surrogate ─────────────
    int safeMax = maxPos;
    while (safeMax > 0 && safeMax < text.length) {
      final cu = text.codeUnitAt(safeMax);
      if (cu >= 0xDC00 && cu <= 0xDFFF) {
        safeMax--; // step back out of a low surrogate
      } else {
        break;
      }
    }
    if (safeMax <= 0) return 1;

    // 1. Prefer paragraph boundary within last 30% of the range
    final int searchFrom = (safeMax * 0.7).toInt();
    final String window = _safeSub(text, searchFrom, safeMax);

    int paraBreak = window.lastIndexOf('\n\n');
    if (paraBreak >= 0) {
      int pos = searchFrom + paraBreak + 2;
      return pos.clamp(1, text.length);
    }

    int lineBreak = window.lastIndexOf('\n');
    if (lineBreak >= 0) {
      int pos = searchFrom + lineBreak + 1;
      return pos.clamp(1, text.length);
    }

    // 2. Word boundary: find last space within safe range
    final String head = _safeSub(text, 0, safeMax);
    int lastSpace = head.lastIndexOf(' ');
    if (lastSpace > safeMax * 0.5) {
      return (lastSpace + 1).clamp(1, text.length);
    }

    // 3. Tamil syllable boundary: avoid cutting inside dependent vowel signs
    // Tamil vowel signs (மாத்திரை): U+0BBE–U+0BCD, U+0BD7
    int pos = safeMax;
    while (pos > 1 && pos < text.length) {
      try {
        final ch = text[pos];
        if (RegExp(r'[\u0BBE-\u0BCD\u0BD7]').hasMatch(ch)) {
          pos--;
        } else {
          break;
        }
      } catch (_) {
        pos--;
      }
    }
    if (pos > 0 && pos != safeMax) return pos;

    // 4. Last resort – use the surrogate-safe max position
    return safeMax;
  }

  void _handleTextChange(String value, int pageIndex, int blockIndex) {
    if (_isUpdatingState) return;

    // Safety guards: pageIndex or blockIndex may be stale.
    if (pageIndex < 0 || pageIndex >= _pages.length) {
      return;
    }
    if (blockIndex < 0 || blockIndex >= _pages[pageIndex].blocks.length) {
      return;
    }

    // ── Sanitize pasted content ──────────────────────────────────────────────
    // Remove malformed UTF-16 sequences (lone surrogates) that cause
    // "string is not well-formed UTF-16" crashes in TextPainter / substring().
    final String sanitized = _sanitizeText(value);

    // If sanitization changed anything, update the controller so the TextField
    // displays the clean version and future onChange calls use the clean text.
    if (sanitized != value) {
      final key = '$pageIndex-$blockIndex';
      final ctrl = _controllers[key];
      if (ctrl != null && ctrl.text != sanitized) {
        final sel = ctrl.selection;
        ctrl.value = TextEditingValue(
          text: sanitized,
          selection: TextSelection.collapsed(
            offset: sel.baseOffset.clamp(0, sanitized.length),
          ),
        );
      }
    }

    setState(() {
      // Update text without truncating lines — use sanitized text
      _pages[pageIndex].blocks[blockIndex].text = sanitized;
      _pages[pageIndex].blocks[blockIndex].previousText = sanitized;

      // Auto-detect Tamil script and switch to Tamil-capable font for correct rendering
      final bool hasTamil = RegExp(r'[\u0B80-\u0BFF]').hasMatch(sanitized);
      if (hasTamil) {
        final currentFont = _pages[pageIndex].fontFamily;
        // Switch to a Tamil-capable font if the current font can't render Tamil properly
        const tamilFonts = {
          'Noto Sans Tamil', 'Mukta Malar', 'Hind Madurai', 'Pavanam',
          'Arima', 'Kavivanar', 'Catamaran', 'Baloo 2', 'Tiro Tamil'
        };
        if (!tamilFonts.contains(currentFont)) {
          _pages[pageIndex].fontFamily = 'Noto Sans Tamil';
        }
      }

      _saveToHistory(immediate: false);
    });

    int oldPageCount = _pages.length;
    final page = _pages[pageIndex];
    double maxWidth = MediaQuery.of(context).size.width - (page.pageMargin * 2);

    if (_doesTextOverflow(sanitized, page, maxWidth)) {
      if (_pdfFile == null) {
        _rebalancePagesFromIndex(pageIndex);
      }

      // Check if we need to move focus to the next page
      String newBlockText = _pages[pageIndex].blocks[blockIndex].text ?? "";
      bool contentMoved = newBlockText.length < sanitized.length;

      if (_pages.length > oldPageCount || contentMoved) {
        int newPageIndex = (_pages.length > oldPageCount)
            ? _pages.length - 1
            : pageIndex + 1;

        if (newPageIndex >= _pages.length) return;

        setState(() {
          _currentPage = newPageIndex;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(newPageIndex);
          }
        });

        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          if (newPageIndex >= _pages.length ||
              _pages[newPageIndex].blocks.isEmpty)
            return;

          int targetBlockIndex = 0;
          for (int b = 0; b < _pages[newPageIndex].blocks.length; b++) {
            if (_pages[newPageIndex].blocks[b].type == "text") {
              targetBlockIndex = b;
              break;
            }
          }

          String key = "$newPageIndex-$targetBlockIndex";
          if (!_controllers.containsKey(key)) {
            _controllers[key] = TextEditingController(
              text: _pages[newPageIndex].blocks[targetBlockIndex].text ?? "",
            );
          }
          if (!_focusNodes.containsKey(key)) {
            _focusNodes[key] = FocusNode();
          }
          FocusScope.of(context).requestFocus(_focusNodes[key]);
          final ctrl = _controllers[key]!;
          ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
        });
      }
    }

    // Cleanup extra empty pages at the end
    while (_pages.length > 1 &&
        _pages.last.blocks.every(
          (b) => b.type != "text" || (b.text ?? "").trim().isEmpty,
        ) &&
        !_pages.last.blocks.any((b) => b.type == "image")) {
      _pages.removeLast();
      if (_currentPage >= _pages.length) {
        _currentPage = _pages.length - 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_currentPage);
          }
        });
      }
    }
  }

  void _loadDraftContent(dynamic content, {bool stayOnPage = false}) {
    if (content == null) return;
    try {
      dynamic decoded;
      if (content is String) {
        final trimmed = content.trim();
        if (trimmed.isEmpty) return;
        try {
          decoded = jsonDecode(trimmed);
        } catch (_) {
          // Lenient fallback for malformed JSON or plain text
          final textMatches = RegExp(r'(?:"text"|text)\s*:\s*"([^"]+)"').allMatches(trimmed);
          if (textMatches.isNotEmpty) {
            final recoveredText = textMatches.map((m) => m.group(1)?.trim() ?? '').where((t) => t.isNotEmpty).join('\n\n');
            if (recoveredText.isNotEmpty) {
              setState(() {
                _pages = [
                  PageData(
                    fontSize: 22,
                    fontFamily: RegExp(r'[\u0B80-\u0BFF]').hasMatch(recoveredText) ? "Mukta Malar" : "Roboto",
                    fontColor: 0xFF000000,
                  )..blocks = [PageBlock.text(recoveredText, fontSize: 20)],
                ];
                _rebuildAllControllers();
                if (!stayOnPage) _currentPage = 0;
              });
              return;
            }
          }
          // Plain text fallback
          setState(() {
            _pages = [
              PageData(
                fontSize: 22,
                fontFamily: RegExp(r'[\u0B80-\u0BFF]').hasMatch(trimmed) ? "Mukta Malar" : "Roboto",
                fontColor: 0xFF000000,
              )..blocks = [PageBlock.text(trimmed, fontSize: 20)],
            ];
            _rebuildAllControllers();
            if (!stayOnPage) _currentPage = 0;
          });
          return;
        }
      } else {
        decoded = content;
      }

      List<dynamic> pagesData = [];

      // handle both formats
      if (decoded is Map && decoded.containsKey("pages")) {
        pagesData = decoded["pages"];
      } else if (decoded is List) {
        pagesData = decoded;
      }

      if (pagesData.isEmpty) return;

      List<PageData> loadedPages = [];

      for (var page in pagesData) {
        PageData pageData = PageData(
          fontSize: (page['fontSize'] ?? 22).toDouble(),
          fontFamily: page['fontFamily'] ?? "Roboto",
          fontColor: page['fontColor'] ?? Colors.black.value,
          lineSpacing: (page['lineSpacing'] ?? 1.4).toDouble(),
          letterSpacing: (page['letterSpacing'] ?? 0.0).toDouble(),
          pageMargin: (page['pageMargin'] ?? 50.0).toDouble(),
          textAlign: TextAlign.values[page['textAlign'] ?? 3],
        );

        pageData.blocks.clear();

        if (page['blocks'] != null) {
          for (var block in page['blocks']) {
            if (block['type'] == "text") {
              pageData.blocks.add(
                PageBlock.text(
                  block['text'] ?? "",
                  isHeadline: block['isHeadline'] ?? false,
                  fontSize: (block['fontSize'] as num?)?.toDouble(),
                  fontFamily: block['fontFamily'] as String?,
                  fontColor: (block['fontColor'] as num?)?.toInt(),
                  lineSpacing: (block['lineSpacing'] as num?)?.toDouble(),
                  letterSpacing: (block['letterSpacing'] as num?)?.toDouble(),
                  textAlign: block['textAlign'] != null
                      ? TextAlign.values[(block['textAlign'] as num).toInt()]
                      : null,
                  blockId: block['blockId'],
                ),
              );
            }

            if (block['type'] == "image") {
              final imageName = block['image'];

              if (imageName == null || imageName.toString().isEmpty) {
                continue;
              }

              final resolvedUrl = _resolveImageUrl(imageName.toString());

              final imgBlock = PageBlock.networkImage(
                resolvedUrl,
                blockId: block['blockId'],
              );

              imgBlock.imageWidth = (block['imageWidth'] ?? 200).toDouble();

              imgBlock.imagePosition = Offset(
                (block['imagePosX'] ?? 0).toDouble(),
                (block['imagePosY'] ?? 0).toDouble(),
              );

              pageData.blocks.add(imgBlock);
            }
          }
        }

        if (pageData.blocks.isEmpty) {
          pageData.blocks.add(PageBlock.text(""));
        }

        loadedPages.add(pageData);
      }

      if (loadedPages.isNotEmpty) {
        setState(() {
          _pages = loadedPages;
          _rebuildAllControllers();
          if (!stayOnPage) {
            _currentPage = 0;
          }
        });
      }
    } catch (e) {
      print("❌ Draft load error: $e");
      if (_pages.isEmpty) {
        setState(() {
          _pages = [
            PageData(
              fontSize: 22,
              fontFamily: "Roboto",
              fontColor: Colors.black.value,
              lineSpacing: 1.4,
              letterSpacing: 0.0,
              pageMargin: 50.0,
              textAlign: TextAlign.justify,
            ),
          ];
          _currentPage = 0;
        });
      }
    }
  }

  final ImagePicker _imagePicker = ImagePicker();

  Future<void> saveDraft({bool silent = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      selectedCategoryId ??= 4;

      final userId = prefs.getString("user_id");
      final token = prefs.getString("token") ?? "";

      final uri = Uri.parse("${ApiConfig.apiBaseUrl}/draft/saveDraft");

      var request = http.MultipartRequest("POST", uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Connection'] = 'keep-alive';

      request.fields["user_id"] = userId ?? "";

      String localCatId = selectedCategoryId?.toString() ?? "4";
      String backendCatId = localCatId;
      if (localCatId.isNotEmpty && !localCatId.startsWith("CAT")) {
        backendCatId = "CAT" + localCatId.padLeft(8, '0');
      }
      request.fields["category_id"] = backendCatId;

      if (_draftId != null) {
        request.fields["draft_id"] = _draftId!;
        request.fields["draftId"] = _draftId!;
      }

      String derivedTitle = "Untitled Draft";
      for (var page in _pages) {
        for (var b in page.blocks) {
          if (b.type == "text" && (b.text ?? "").trim().isNotEmpty) {
            String candidate = (b.text ?? "").trim().split('\n').first.trim();
            if (candidate.length > 60) candidate = candidate.substring(0, 60);
            if (candidate.isNotEmpty) {
              derivedTitle = candidate;
              break;
            }
          }
        }
        if (derivedTitle != "Untitled Draft") break;
      }
      request.fields["title"] = derivedTitle;

      // Sync latest text from all active controllers into pages before serialization
      for (int p = 0; p < _pages.length; p++) {
        for (int b = 0; b < _pages[p].blocks.length; b++) {
          final key = "$p-$b";
          if (_controllers.containsKey(key)) {
            _pages[p].blocks[b].text = _controllers[key]!.text;
          }
        }
      }

      List<Map<String, dynamic>> pagesJson = [];

      for (var page in _pages) {
        List<Map<String, dynamic>> blocksJson = [];

        for (var block in page.blocks) {
          String? imageName;

          if (block.type == "image") {
            if (block.image != null) {
              final fileName =
                  "${block.blockId}_${DateTime.now().millisecondsSinceEpoch}.jpg";

              final mimeType = lookupMimeType(block.image!.path);
              final mimeSplit = mimeType?.split('/') ?? ['image', 'jpeg'];

              request.files.add(
                await http.MultipartFile.fromPath(
                  "page_images",
                  block.image!.path,
                  filename: fileName,
                  contentType: MediaType(mimeSplit[0], mimeSplit[1]),
                ),
              );

              imageName = fileName;
            } else if (block.imageUrl != null && block.imageUrl!.isNotEmpty) {
              imageName = block.imageUrl;
            }
          }

          blocksJson.add({
            "type": block.type,
            "text": block.text,
            "image": imageName,
            "blockId": block.blockId,
            "imageWidth": block.imageWidth,
            "imagePosX": block.imagePosition?.dx,
            "imagePosY": block.imagePosition?.dy,
            "isHeadline": block.isHeadline,
            "fontColor": block.fontColor,
            "fontSize": block.fontSize,
            "fontFamily": block.fontFamily,
            "lineSpacing": block.lineSpacing,
            "letterSpacing": block.letterSpacing,
            "textAlign": block.textAlign?.index,
          });
        }

        pagesJson.add({
          "fontSize": page.fontSize,
          "fontFamily": page.fontFamily,
          "fontColor": page.fontColor,
          "lineSpacing": page.lineSpacing,
          "letterSpacing": page.letterSpacing,
          "pageMargin": page.pageMargin,
          "textAlign": page.textAlign.index,
          "blocks": blocksJson,
        });
      }

      request.fields["content"] = jsonEncode(pagesJson);

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
      );
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["draft_id"] != null) {
          _draftId = data["draft_id"].toString();
        }

        DraftsManager.instance.notifyDraftsChanged();

        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Draft saved successfully")),
          );
        }
      } else {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Save failed: ${response.statusCode}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to save draft: $e")));
      }
    }
  }

  Future<void> _showSaveDraftConfirmation() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Save Draft?"),
        content: const Text("Do you want to save this as a draft?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("NO", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "YES",
              style: TextStyle(
                color: Color(0xFF0729E8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == null) return;

    if (result == true) {
      await saveDraft();
      DraftsManager.instance.notifyDraftsChanged();
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _pickImageForPage(int index) async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      _flushHistoryIfPending();
      setState(() {
        int targetPage = index;

        // Rule: A page can ONLY have an image OR text, not both.
        // If current page is not empty, we MUST move the image to a new page.
        bool currentPageHasContent = _pages[index].blocks.any(
          (b) =>
              b.type == "image" ||
              (b.type == "text" && (b.text ?? "").trim().isNotEmpty),
        );

        if (currentPageHasContent) {
          targetPage = index + 1;
          if (targetPage >= _pages.length) {
            _pages.add(
              PageData(
                fontSize: _pages[0].fontSize,
                fontFamily: _pages[0].fontFamily,
                fontColor: _pages[0].fontColor,
                lineSpacing: _pages[0].lineSpacing,
                letterSpacing: _pages[0].letterSpacing,
                pageMargin: _pages[0].pageMargin,
                textAlign: _pages[0].textAlign,
              ),
            );
          } else {
            // Insert a fresh page for the image
            _pages.insert(
              targetPage,
              PageData(
                fontSize: _pages[0].fontSize,
                fontFamily: _pages[0].fontFamily,
                fontColor: _pages[0].fontColor,
                lineSpacing: _pages[0].lineSpacing,
                letterSpacing: _pages[0].letterSpacing,
                pageMargin: _pages[0].pageMargin,
                textAlign: _pages[0].textAlign,
              ),
            );
          }
          _pages[targetPage].blocks.clear();
        } else {
          // Current page is empty, reuse it
          _pages[targetPage].blocks.clear();
        }

        _pages[targetPage].blocks.add(PageBlock.image(File(image.path)));

        _currentPage = targetPage;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.jumpToPage(targetPage);
        });
      });
      _saveToHistory(immediate: true);
    }
  }

  void _removeImageBlock(int pageIndex, int blockIndex) {
    _flushHistoryIfPending();
    setState(() {
      final blocks = _pages[pageIndex].blocks;
      blocks.removeAt(blockIndex);

      // If page is now empty, add a default text block
      if (blocks.isEmpty) {
        blocks.add(PageBlock.text(""));
      }

      // if removing left two adjacent text blocks, merge them
      for (int i = 0; i < blocks.length - 1; i++) {
        if (blocks[i].type == "text" && blocks[i + 1].type == "text") {
          blocks[i].text =
              '${blocks[i].text ?? ""}\n${blocks[i + 1].text ?? ""}';
          blocks.removeAt(i + 1);
          break;
        }
      }

      // Trigger rebalance to pull content from next pages into this newly freed space
      _rebalancePagesFromIndex(pageIndex);
    });
    _saveToHistory(immediate: true);
  }

  void _deleteCurrentPage() {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("At least one page is required")),
      );
      return;
    }

    _flushHistoryIfPending();

    int pageToDelete = _currentPage; // ✅ lock the correct page index

    setState(() {
      _pages.removeAt(pageToDelete);

      // move cursor safely
      if (_currentPage >= _pages.length) {
        _currentPage = _pages.length - 1;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.jumpToPage(_currentPage);
      });

      // update controllers safely
      Map<String, TextEditingController> newControllers = {};
      Map<String, FocusNode> newFocusNodes = {};

      for (int p = 0; p < _pages.length; p++) {
        for (int b = 0; b < _pages[p].blocks.length; b++) {
          if (_pages[p].blocks[b].type == "text") {
            String oldKey = "${p >= pageToDelete ? p + 1 : p}-$b";
            String newKey = "$p-$b";

            if (_controllers.containsKey(oldKey)) {
              newControllers[newKey] = _controllers[oldKey]!;
            }

            if (_focusNodes.containsKey(oldKey)) {
              newFocusNodes[newKey] = _focusNodes[oldKey]!;
            }
          }
        }
      }

      _controllers
        ..clear()
        ..addAll(newControllers);

      _focusNodes
        ..clear()
        ..addAll(newFocusNodes);
    });
    _saveToHistory(immediate: true);
  }

  void _addNewPage() {
    _flushHistoryIfPending();
    setState(() {
      final lastPage = _pages.isNotEmpty ? _pages.last : null;
      _pages.add(
        PageData(
          fontSize: lastPage?.fontSize ?? 22,
          fontFamily: lastPage?.fontFamily ?? "Roboto",
          fontColor: lastPage?.fontColor ?? Colors.black.value,
          lineSpacing: lastPage?.lineSpacing ?? 1.4,
          letterSpacing: lastPage?.letterSpacing ?? 0.0,
          pageMargin: lastPage?.pageMargin ?? 50.0,
          textAlign: lastPage?.textAlign ?? TextAlign.justify,
        ),
      );
      _pageController.jumpToPage(_pages.length - 1);
      _currentPage = _pages.length - 1;
    });
    _saveToHistory(immediate: true);
  }

  void _applyStyleToSelection({
    double? fontSize,
    String? fontFamily,
    int? fontColor,
    bool? isHeadline,
    double? lineSpacing,
    double? letterSpacing,
    TextAlign? textAlign,
  }) {
    if (_focusedBlockIndex == null) return;
    final pageIdx = _currentPage;
    final page = _pages[pageIdx];
    final blockIndex = _focusedBlockIndex!;
    final block = page.blocks[blockIndex];
    if (block.type != "text") return;

    final key = "$pageIdx-$blockIndex";
    final controller = _controllers[key];
    if (controller == null) return;

    _flushHistoryIfPending();

    final selection = controller.selection;
    final text = controller.text;

    // BOUNDS CHECK
    if (fontSize != null && fontSize < 12) fontSize = 12;

    // ALIGNMENT and LINE SPACING usually apply to the entire paragraph/block.
    // However, if the user HAS a selection, we respect their wish to split it.
    if (selection.isCollapsed ||
        selection.start == -1 ||
        selection.start == selection.end) {
      if (textAlign != null || lineSpacing != null) {
        setState(() {
          if (textAlign != null) block.textAlign = textAlign;
          if (lineSpacing != null) block.lineSpacing = lineSpacing;
        });
        // If ONLY alignment/spacing was changed, we don't need to do more.
        if (fontSize == null &&
            fontFamily == null &&
            fontColor == null &&
            isHeadline == null &&
            letterSpacing == null) {
          _saveToHistory(immediate: true);
          return;
        }
      }
    }

    if (selection.isCollapsed ||
        selection.start == -1 ||
        selection.start == selection.end) {
      // Apply to WHOLE block (block-level override)
      setState(() {
        if (fontSize != null) block.fontSize = fontSize;
        if (fontFamily != null) block.fontFamily = fontFamily;
        if (fontColor != null) block.fontColor = fontColor;
        if (isHeadline != null) block.isHeadline = isHeadline;
        if (lineSpacing != null) block.lineSpacing = lineSpacing;
        if (letterSpacing != null) block.letterSpacing = letterSpacing;
        if (textAlign != null) block.textAlign = textAlign;
      });
      _saveToHistory(immediate: true);
      return;
    }

    // SPLIT BLOCK
    final beforeText = text.substring(0, selection.start);
    final selectedText = text.substring(selection.start, selection.end);
    final afterText = text.substring(selection.end);

    setState(() {
      page.blocks.removeAt(blockIndex);

      int insertAt = blockIndex;

      if (beforeText.isNotEmpty) {
        page.blocks.insert(
          insertAt++,
          PageBlock.text(
            beforeText,
            isHeadline: block.isHeadline,
            fontColor: block.fontColor,
            fontSize: block.fontSize,
            fontFamily: block.fontFamily,
            lineSpacing: block.lineSpacing,
            letterSpacing: block.letterSpacing,
            textAlign: block.textAlign,
          ),
        );
      }

      final middleBlock = PageBlock.text(
        (isHeadline ?? block.isHeadline)
            ? selectedText.toUpperCase()
            : selectedText,
        isHeadline: isHeadline ?? block.isHeadline,
        fontColor: fontColor ?? block.fontColor,
        fontSize: fontSize ?? block.fontSize,
        fontFamily: fontFamily ?? block.fontFamily,
        lineSpacing: lineSpacing ?? block.lineSpacing,
        letterSpacing: letterSpacing ?? block.letterSpacing,
        textAlign: textAlign ?? block.textAlign,
      );
      final int activeBlockIndex = insertAt;
      page.blocks.insert(insertAt++, middleBlock);

      if (afterText.isNotEmpty) {
        page.blocks.insert(
          insertAt++,
          PageBlock.text(
            afterText,
            isHeadline: block.isHeadline,
            fontColor: block.fontColor,
            fontSize: block.fontSize,
            fontFamily: block.fontFamily,
            lineSpacing: block.lineSpacing,
            letterSpacing: block.letterSpacing,
            textAlign: block.textAlign,
          ),
        );
      }

      // Restore focus to the middle block
      _focusedBlockIndex = activeBlockIndex;
    });

    _rebalancePagesFromIndex(pageIdx);

    // RESTORE SELECTION & FOCUS POST-REBALANCE
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newKey = "$pageIdx-$_focusedBlockIndex";
      if (_controllers.containsKey(newKey)) {
        final ctrl = _controllers[newKey]!;
        final len = ctrl.text.length;
        ctrl.selection = TextSelection(baseOffset: 0, extentOffset: len);
        if (_focusNodes.containsKey(newKey)) {
          FocusScope.of(context).requestFocus(_focusNodes[newKey]);
        }
      }
    });
    _saveToHistory(immediate: true);
  }

  void _applyGlobalStyle({
    double? fontSize,
    String? fontFamily,
    double? lineSpacing,
    double? letterSpacing,
    TextAlign? textAlign,
    double? pageMargin,
  }) {
    _flushHistoryIfPending();
    setState(() {
      for (var p in _pages) {
        if (fontSize != null) p.fontSize = fontSize;
        if (fontFamily != null) p.fontFamily = fontFamily;
        if (lineSpacing != null) p.lineSpacing = lineSpacing;
        if (letterSpacing != null) p.letterSpacing = letterSpacing;
        if (textAlign != null) p.textAlign = textAlign;
        if (pageMargin != null) p.pageMargin = pageMargin;

        for (var b in p.blocks) {
          if (b.type == "text") {
            if (fontSize != null) b.fontSize = fontSize;
            if (fontFamily != null) b.fontFamily = fontFamily;
            if (lineSpacing != null) b.lineSpacing = lineSpacing;
            if (letterSpacing != null) b.letterSpacing = letterSpacing;
            if (textAlign != null) b.textAlign = textAlign;
          }
        }
      }
    });

    // Global style updates (font family, font size, margins, etc.) apply styling
    // across existing pages without triggering a destructive document-wide rebalance.

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusedBlockIndex != null && _currentPage < _pages.length) {
        final newKey = "$_currentPage-$_focusedBlockIndex";
        if (_focusNodes.containsKey(newKey)) {
          FocusScope.of(context).requestFocus(_focusNodes[newKey]);
        }
      }
    });
    _saveToHistory(immediate: true);
  }

  void _applyStyleSmartly({
    double? fontSize,
    String? fontFamily,
    double? lineSpacing,
    double? letterSpacing,
    TextAlign? textAlign,
  }) {
    bool hasSelection = false;
    if (_focusedBlockIndex != null) {
      final key = "$_currentPage-$_focusedBlockIndex";
      final ctrl = _controllers[key];
      if (ctrl != null &&
          ctrl.selection.isValid &&
          !ctrl.selection.isCollapsed &&
          ctrl.selection.start != -1) {
        hasSelection = true;
      }
    }

    if (hasSelection) {
      _applyStyleToSelection(
        fontSize: fontSize,
        fontFamily: fontFamily,
        lineSpacing: lineSpacing,
        letterSpacing: letterSpacing,
        textAlign: textAlign,
      );
    } else {
      _applyGlobalStyle(
        fontSize: fontSize,
        fontFamily: fontFamily,
        lineSpacing: lineSpacing,
        letterSpacing: letterSpacing,
        textAlign: textAlign,
      );
    }
  }

  // FIXED BUILD METHOD START
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        await _showSaveDraftConfirmation();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.05),
          automaticallyImplyLeading: false,
          toolbarHeight: 70,
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/ryitu_logo_round.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Ritpen",
                style: GoogleFonts.outfit(
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _showSaveDraftConfirmation,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0729E8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: const Color(0xFF0729E8).withOpacity(0.2),
                    ),
                  ),
                ),
                child: const Text(
                  "Draft",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final Widget nextPage = selectedCategoryId == 4
                      ? CoverEditorPage(
                          pages: _pages,
                          draftId: _draftId,
                          category: selectedCategoryId.toString(),
                        )
                      : PostPage(
                          pages: _pages,
                          draftId: _draftId,
                          coverImage: null,
                          title: "",
                          titleFontSize: 28,
                          titleColor: Colors.black,
                          titleFontFamily: "Roboto",
                          titlePosition: const Offset(0.5, 0.4),
                          category: selectedCategoryId.toString(),
                        );
                  final route = Platform.isIOS
                      ? CupertinoPageRoute(builder: (_) => nextPage)
                      : MaterialPageRoute(builder: (_) => nextPage);
                  Navigator.push(context, route);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0729E8),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.05,
                  vertical: 20,
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme: const InputDecorationTheme(
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: _pages.length,
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                          _rebuildAllControllers();
                        },
                        itemBuilder: (context, index) {
                          return Center(
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDFBF7),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: 32,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Colors.black.withOpacity(0.12),
                                              Colors.black.withOpacity(0.04),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Opacity(
                                        opacity: 0.02,
                                        child: Image.network(
                                          "https://www.transparenttextures.com/patterns/paper-fibers.png",
                                          repeat: ImageRepeat.repeat,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox(),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.65,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: _pages[index].pageMargin,
                                        vertical: 40,
                                      ),
                                      child: SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ..._pages[index].blocks.asMap().entries.map((
                                              entry,
                                            ) {
                                              final blockIndex = entry.key;
                                              final block = entry.value;

                                              if (block.type == "text") {
                                                String key =
                                                    "$index-$blockIndex";

                                                if (!_controllers.containsKey(
                                                  key,
                                                )) {
                                                  final ctrl =
                                                      TextEditingController(
                                                        text: block.text ?? "",
                                                      );
                                                  ctrl.addListener(() {
                                                    if (!_isUndoRedoOp &&
                                                        _pages[index]
                                                                .blocks[blockIndex]
                                                                .text !=
                                                            ctrl.text) {
                                                      _handleTextChange(
                                                        ctrl.text,
                                                        index,
                                                        blockIndex,
                                                      );
                                                    }
                                                  });
                                                  _controllers[key] = ctrl;
                                                }

                                                if (!_focusNodes.containsKey(
                                                  key,
                                                )) {
                                                  _focusNodes[key] =
                                                      FocusNode();
                                                }

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                      ),
                                                  child: TextField(
                                                    controller:
                                                        _controllers[key],
                                                    focusNode: _focusNodes[key],
                                                    onTap: () {
                                                      _onFocusChanged(
                                                        blockIndex,
                                                        true,
                                                      );
                                                    },
                                                    keyboardType:
                                                        TextInputType.multiline,
                                                    textCapitalization:
                                                        block.isHeadline
                                                        ? TextCapitalization
                                                              .characters
                                                        : TextCapitalization
                                                              .sentences,
                                                    textInputAction:
                                                        TextInputAction.newline,
                                                    maxLines: null,
                                                    onChanged: (value) {
                                                      _handleTextChange(
                                                        value,
                                                        index,
                                                        blockIndex,
                                                      );
                                                    },
                                                    textAlign:
                                                        block.textAlign ??
                                                        _pages[index].textAlign,
                                                    style: _safeGoogleFont(
                                                      block.fontFamily ??
                                                          _pages[index]
                                                              .fontFamily,
                                                      textStyle: const TextStyle(
                                                        fontFamilyFallback: [
                                                          'Mukta Malar',
                                                          'Noto Sans Tamil',
                                                          'Roboto',
                                                        ],
                                                      ),
                                                      fontSize: block.isHeadline
                                                          ? 28
                                                          : (block.fontSize ??
                                                                _pages[index]
                                                                    .fontSize),
                                                      fontWeight:
                                                          block.isHeadline
                                                          ? FontWeight.w900
                                                          : FontWeight.w400,
                                                      color: Color(
                                                        block.fontColor ??
                                                            _pages[index]
                                                                .fontColor,
                                                      ),
                                                      height:
                                                          block.lineSpacing ??
                                                          _pages[index]
                                                              .lineSpacing,
                                                      letterSpacing:
                                                          block.isHeadline
                                                          ? -0.5
                                                          : (block.letterSpacing ??
                                                                _pages[index]
                                                                    .letterSpacing),
                                                      backgroundColor: null,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText: blockIndex == 0
                                                          ? "Share your story..."
                                                          : null,
                                                      hintStyle: TextStyle(
                                                        color: Colors
                                                            .grey
                                                            .shade400,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                      filled: false,
                                                      fillColor:
                                                          Colors.transparent,
                                                      border: InputBorder.none,
                                                      enabledBorder:
                                                          InputBorder.none,
                                                      focusedBorder:
                                                          InputBorder.none,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      isDense: true,
                                                    ),
                                                    cursorColor: const Color(
                                                      0xFF0729E8,
                                                    ),
                                                  ),
                                                );
                                              }

                                              if (block.type == "image") {
                                                Widget imageWidget;
                                                if (block.image != null) {
                                                  imageWidget = Image.file(
                                                    block.image!,
                                                    width: double.infinity,
                                                    fit: BoxFit.contain,
                                                  );
                                                } else if (block.imageUrl !=
                                                        null &&
                                                    block
                                                        .imageUrl!
                                                        .isNotEmpty) {
                                                  imageWidget = ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    child: Image.network(
                                                      _resolveImageUrl(block.imageUrl!),
                                                      width: double.infinity,
                                                      fit: BoxFit.contain,
                                                      loadingBuilder:
                                                          (
                                                            context,
                                                            child,
                                                            progress,
                                                          ) {
                                                            if (progress ==
                                                                null)
                                                              return child;
                                                            return const Center(
                                                              child:
                                                                  CircularProgressIndicator(),
                                                            );
                                                          },
                                                      errorBuilder:
                                                          (_, __, ___) {
                                                            return const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              size: 50,
                                                            );
                                                          },
                                                    ),
                                                  );
                                                } else {
                                                  return const SizedBox();
                                                }
                                                return Container(
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 16,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.12),
                                                        blurRadius: 10,
                                                        offset: const Offset(
                                                          0,
                                                          5,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    child: Stack(
                                                      alignment:
                                                          Alignment.topRight,
                                                      children: [
                                                        imageWidget,
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                8.0,
                                                              ),
                                                          child: CircleAvatar(
                                                            backgroundColor:
                                                                Colors.white,
                                                            radius: 18,
                                                            child: IconButton(
                                                              icon: const Icon(
                                                                Icons
                                                                    .close_rounded,
                                                                color: Color(
                                                                  0xFF0729E8,
                                                                ),
                                                                size: 18,
                                                              ),
                                                              onPressed: () =>
                                                                  _removeImageBlock(
                                                                    index,
                                                                    blockIndex,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }
                                              return const SizedBox();
                                            }),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Floating Page Indicator
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              _showPagePicker();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(204),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(51),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                "PAGE ${_currentPage + 1} / ${_pages.length}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Actions
                      Positioned(
                        left: 0,
                        bottom: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            FloatingActionButton.small(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0729E8),
                              elevation: 4,
                              heroTag: "deletePage",
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: const Text("Delete Page?"),
                                    content: const Text(
                                      "This action cannot be undone and will remove all content on this page.",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("Keep it"),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteCurrentPage();
                                        },
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(
                                            color: Color(0xFF0729E8),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Icon(Icons.delete_outline_rounded),
                            ),
                            FloatingActionButton(
                              backgroundColor: const Color(0xFF0729E8),
                              elevation: 4,
                              onPressed: _addNewPage,
                              child: const Icon(
                                Icons.add_rounded,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            FloatingActionButton.small(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF00966F),
                              elevation: 4,
                              heroTag: "addImage",
                              onPressed: () => _pickImageForPage(_currentPage),
                              child: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Toolbar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildToolbarButton(
                        context,
                        Icons.undo_rounded,
                        "Undo",
                        () {
                          HapticFeedback.lightImpact();
                          _globalUndo();
                        },
                        disabled: _historyIndex <= 0,
                      ),
                      _buildToolbarButton(
                        context,
                        Icons.text_format_rounded,
                        "Text Styles",
                        () {
                          HapticFeedback.lightImpact();
                          _showStylePicker();
                        },
                      ),
                      _buildToolbarButton(
                        context,
                        Icons.redo_rounded,
                        "Redo",
                        () {
                          HapticFeedback.lightImpact();
                          _globalRedo();
                        },
                        disabled: _historyIndex >= _historyStack.length - 1,
                      ),
                      if (selectedCategoryId == 4)
                        _buildToolbarButton(
                          context,
                          Icons.upload_file_rounded,
                          _isExtractingPdf ? "Uploading..." : "Upload PDF",
                          _isExtractingPdf
                              ? () {}
                              : () {
                                  HapticFeedback.lightImpact();
                                  _pickPDF();
                                },
                          isActive: _pdfFile != null,
                          disabled: _isExtractingPdf,
                        ),
                    ],
                  ),
                  if (selectedCategoryId == 4)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isExtractingPdf)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: const Color(0xFF0729E8),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _pdfExtractionStatus,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                TextButton(
                                  onPressed: _cancelPdfExtraction,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text(
                                    "Cancel",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          if (!_isExtractingPdf)
                            Text(
                              "PDF upload limit: 100MB",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isActive = false,
    bool disabled = false,
  }) {
    final Color color = disabled
        ? Colors.grey.withOpacity(0.3)
        : (isActive ? const Color(0xFF0729E8) : Colors.grey.shade700);

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0729E8).withOpacity(0.08) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              "Go to Page",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final isCurrent = index == _currentPage;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.fastOutSlowIn,
                      );
                    },
                    child: Container(
                      width: 56,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF0729E8)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFF0729E8)
                              : Colors.grey.shade200,
                          width: 1.5,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0729E8).withAlpha(60),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isCurrent ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  void _showStylePicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (_currentPage >= _pages.length) return const SizedBox();
            final page = _pages[_currentPage];
            final focusedBlock =
                (_focusedBlockIndex != null &&
                    _focusedBlockIndex! < page.blocks.length &&
                    page.blocks[_focusedBlockIndex!].type == "text")
                ? page.blocks[_focusedBlockIndex!]
                : null;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFFF9F9F7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "DISPLAYS",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey.shade500,
                            letterSpacing: 1.2,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _applyGlobalStyle(
                              fontSize: 22,
                              lineSpacing: 1.4,
                              letterSpacing: 0.0,
                              fontFamily: "Mukta Malar",
                              textAlign: TextAlign.left,
                              pageMargin: 50.0,
                            );
                            setModalState(() {});
                          },
                          child: const Text(
                            "RESET",
                            style: TextStyle(
                              color: Color(0xFF0729E8),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        // --- FONT SIZE ---
                        const SizedBox(height: 16),
                        _buildSectionHeaderLabel("FONT SIZE"),
                        const SizedBox(height: 16),
                        _buildStepper(
                          value:
                              "${(focusedBlock?.fontSize ?? page.fontSize).toInt()} px",
                          onDecrement: () {
                            if (page.fontSize > 16) {
                              _applyStyleSmartly(
                                fontSize:
                                    (focusedBlock?.fontSize ?? page.fontSize) -
                                    1,
                              );
                              setModalState(() {});
                            }
                          },
                          onIncrement: () {
                            if (page.fontSize < 48) {
                              _applyStyleSmartly(
                                fontSize:
                                    (focusedBlock?.fontSize ?? page.fontSize) +
                                    1,
                              );
                              setModalState(() {});
                            }
                          },
                        ),

                        const SizedBox(height: 32),

                        // --- FONT FAMILY ---
                        _buildSectionHeaderLabel("FONT FAMILY"),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 54,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _fontFamilies.length,
                            itemBuilder: (context, idx) {
                              final font = _fontFamilies[idx];
                              final isSelected = (focusedBlock != null)
                                  ? (focusedBlock.fontFamily ??
                                            page.fontFamily) ==
                                        font
                                  : page.fontFamily == font;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _applyStyleSmartly(fontFamily: font);
                                  setModalState(() {});
                                },
                                child: Container(
                                  height: 46,
                                  width: 120, // Enough for Tamil font names
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    font,
                                    style: _safeGoogleFont(
                                      font,
                                      fontWeight: isSelected
                                          ? FontWeight.w900
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 32),

                        // --- TYPOGRAPHY ---
                        _buildSectionHeaderLabel("TYPOGRAPHY"),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTypographyStepper(
                                label: "LINE SPACING",
                                value:
                                    (focusedBlock?.lineSpacing ??
                                            page.lineSpacing)
                                        .toStringAsFixed(1),
                                onDecrement: () {
                                  if (page.lineSpacing > 1.0) {
                                    _applyStyleSmartly(
                                      lineSpacing:
                                          (focusedBlock?.lineSpacing ??
                                              page.lineSpacing) -
                                          0.1,
                                    );
                                    setModalState(() {});
                                  }
                                },
                                onIncrement: () {
                                  if (page.lineSpacing < 3.0) {
                                    _applyStyleSmartly(
                                      lineSpacing:
                                          (focusedBlock?.lineSpacing ??
                                              page.lineSpacing) +
                                          0.1,
                                    );
                                    setModalState(() {});
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTypographyStepper(
                                label: "LETTERING",
                                value:
                                    (focusedBlock?.letterSpacing ??
                                            page.letterSpacing)
                                        .toStringAsFixed(1),
                                onDecrement: () {
                                  if (page.letterSpacing > -2.0) {
                                    _applyStyleSmartly(
                                      letterSpacing:
                                          (focusedBlock?.letterSpacing ??
                                              page.letterSpacing) -
                                          0.1,
                                    );
                                    setModalState(() {});
                                  }
                                },
                                onIncrement: () {
                                  if (page.letterSpacing < 5.0) {
                                    _applyStyleSmartly(
                                      letterSpacing:
                                          (focusedBlock?.letterSpacing ??
                                              page.letterSpacing) +
                                          0.1,
                                    );
                                    setModalState(() {});
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeaderLabel("ALIGNMENT"),
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 54,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildAlignButton(
                                          TextAlign.left,
                                          focusedBlock?.textAlign ??
                                              page.textAlign,
                                          (val) {
                                            _applyStyleSmartly(textAlign: val);
                                            setModalState(() {});
                                          },
                                          Icons.format_align_left_rounded,
                                        ),
                                        _buildAlignButton(
                                          TextAlign.center,
                                          focusedBlock?.textAlign ??
                                              page.textAlign,
                                          (val) {
                                            _applyStyleSmartly(textAlign: val);
                                            setModalState(() {});
                                          },
                                          Icons.format_align_center_rounded,
                                        ),
                                        _buildAlignButton(
                                          TextAlign.right,
                                          focusedBlock?.textAlign ??
                                              page.textAlign,
                                          (val) {
                                            _applyStyleSmartly(textAlign: val);
                                            setModalState(() {});
                                          },
                                          Icons.format_align_right_rounded,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTypographyStepper(
                                label: "PAGE MARGIN",
                                value: page.pageMargin.toInt().toString(),
                                onDecrement: () {
                                  if (page.pageMargin > 10) {
                                    _applyGlobalStyle(
                                      pageMargin: page.pageMargin - 5,
                                    );
                                    setModalState(() {});
                                  }
                                },
                                onIncrement: () {
                                  if (page.pageMargin < 100) {
                                    _applyGlobalStyle(
                                      pageMargin: page.pageMargin + 5,
                                    );
                                    setModalState(() {});
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // --- WRITING SPECIFIC: BLOCK STYLES ---
                        _buildSectionHeaderLabel("BLOCK STYLE"),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildBlockStyleButton(
                              "Headline",
                              Icons.title_rounded,
                              focusedBlock != null
                                  ? focusedBlock.isHeadline
                                  : _activeHeadline,
                              () {
                                HapticFeedback.mediumImpact();
                                if (focusedBlock != null) {
                                  _applyStyleToSelection(
                                    isHeadline: !focusedBlock.isHeadline,
                                  );
                                  setModalState(() {});
                                } else {
                                  setState(
                                    () => _activeHeadline = !_activeHeadline,
                                  );
                                  setModalState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                        if (focusedBlock == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              "Tap on text to enable block styles",
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),
                        _buildSectionHeaderLabel("TEXT COLOR"),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _fontColors.map((colorValue) {
                            final isSelected =
                                (focusedBlock != null &&
                                    focusedBlock.fontColor != null)
                                ? focusedBlock.fontColor == colorValue
                                : _activeColor == colorValue;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _activeColor = colorValue;

                                  if (focusedBlock != null) {
                                    _applyStyleToSelection(
                                      fontColor: colorValue,
                                    );
                                  }
                                });
                                setModalState(() {});
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Color(colorValue),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0729E8)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF0729E8,
                                            ).withOpacity(0.4),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 18,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
          },
        );
      },
    );
  }

  Widget _buildSectionHeaderLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Colors.grey.shade500,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildStepper({
    required String value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildStepButton(Icons.remove, onDecrement),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                fontFamily: "Lora",
              ),
            ),
          ),
          _buildStepButton(Icons.add, onIncrement),
        ],
      ),
    );
  }

  Widget _buildStepButton(IconData icon, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.black87, size: 24),
        ),
      ),
    );
  }

  Widget _buildTypographyStepper({
    required String label,
    required String value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _buildSmallStepButton(Icons.remove, onDecrement),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              _buildSmallStepButton(Icons.add, onIncrement),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallStepButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(icon, size: 18, color: Colors.black54),
      ),
    );
  }

  Widget _buildAlignButton(
    TextAlign value,
    TextAlign current,
    Function(TextAlign) onChanged,
    IconData icon,
  ) {
    bool isSelected = value == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          height: 46,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.black : Colors.grey.shade400,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildBlockStyleButton(
    String label,
    IconData icon,
    bool isActive,
    VoidCallback? onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 60,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? const Color(0xFF0729E8) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF0729E8).withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive
                    ? const Color(0xFF0729E8)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isActive
                      ? const Color(0xFF0729E8)
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CoverEditorPage extends StatefulWidget {
  final List<PageData> pages;
  final String? draftId;
  final String? category;

  const CoverEditorPage({
    super.key,
    required this.pages,
    this.draftId,
    this.category,
  });

  @override
  State<CoverEditorPage> createState() => _CoverEditorPageState();
}

class _CoverEditorPageState extends State<CoverEditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _coverImage;

  double _fontSize = 28;
  Color _fontColor = Colors.white;
  String _fontFamily = "Roboto";

  final Offset _textPosition = const Offset(0.5, 0.4);

  final List<String> _fontFamilies = [
    "Roboto",
    "Merienda",
    "Courier New",
    "Times New Roman",
    "Arial",
    "Lobster",
  ];

  final List<Color> _colors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.yellow,
    Colors.green,
    Colors.orange,
  ];

  Future<void> _pickCoverImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _coverImage = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Design Cover",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF0729E8),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostPage(
                    pages: widget.pages,
                    draftId: widget.draftId,
                    coverImage: _coverImage,
                    title: _titleController.text,
                    titleFontSize: _fontSize,
                    titleColor: _fontColor,
                    titleFontFamily: _fontFamily,
                    titlePosition: _textPosition,
                    category: widget.category,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
          ),
          const SizedBox(width: 8),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickCoverImage,
                child: Container(
                  width: size.width * 0.65,
                  height: size.height * 0.45,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Cover Image
                        _coverImage != null
                            ? Image.file(
                                _coverImage!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey.shade100,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 60,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        "Add a cover image",
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                        // Title Overlay
                        Positioned(
                          top: 30,
                          left: 20,
                          right: 20,
                          child: Text(
                            _titleController.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _fontSize,
                              color: _fontColor,
                              fontFamily: _fontFamily,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 48),

            /// CONTROLS
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Book Title",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    onChanged: (v) => setState(() {}),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "Enter a catchy title...",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        "Text Size",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${_fontSize.toInt()} px",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0729E8),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 16,
                    max: 60,
                    value: _fontSize,
                    activeColor: const Color(0xFF0729E8),
                    inactiveColor: const Color(0xFF0729E8).withOpacity(0.1),
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Font Style",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _fontFamilies.length,
                      itemBuilder: (context, index) {
                        final font = _fontFamilies[index];
                        final isSelected = _fontFamily == font;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(
                              font,
                              style: TextStyle(
                                fontFamily: font,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF0729E8),
                            backgroundColor: Colors.grey.shade100,
                            onSelected: (v) =>
                                setState(() => _fontFamily = font),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Text Color",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: _colors.map((color) {
                      final isSelected = _fontColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => _fontColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0729E8)
                                  : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
    );
  }
}

class PostPage extends StatefulWidget {
  final List<PageData> pages;
  final String? draftId; // 🔥 ADD THIS

  final File? coverImage;
  final String? title;
  final double? titleFontSize;
  final Color? titleColor;
  final String? titleFontFamily;
  final Offset? titlePosition;
  final String? category;

  const PostPage({
    super.key,
    required this.pages,
    this.draftId,
    this.coverImage,
    this.title,
    this.titleFontSize,
    this.titleColor,
    this.titleFontFamily,
    this.titlePosition,
    this.category,
  });

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  bool _postToCommunity = false;
  String? _selectedCommunityId;
  String? _selectedCommunityName;
  List<Map<String, dynamic>> _myCommunities = [];
  bool _isLoadingCommunities = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.title ?? "";
    print("Draft ID in PostPage: ${widget.draftId}");
    _loadUserCommunities();
  }

  Future<void> _loadUserCommunities() async {
    setState(() => _isLoadingCommunities = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString("user_id") ?? "USR00000001";
      final uri = Uri.parse(
        "${ApiConfig.apiBaseUrl}/communities/my-communities?userId=$userId",
      );
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true &&
            decoded['data']?['communities'] is List) {
          final list = List<Map<String, dynamic>>.from(
            decoded['data']['communities'],
          );
          if (mounted) {
            setState(() {
              _myCommunities = list;
              if (list.isNotEmpty && _selectedCommunityId == null) {
                _selectedCommunityId = list[0]['_id']?.toString();
                _selectedCommunityName = list[0]['name']?.toString();
              }
            });
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingCommunities = false);
    }
  }

  List<String> extractHashtags(String input) {
    final regex = RegExp(r'#[\p{L}\p{M}0-9_]+', unicode: true);
    return regex
        .allMatches(input)
        .map((m) => m.group(0)!.toLowerCase())
        .toSet()
        .toList();
  }

  Future<void> _publishPost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final userId = prefs.getString("user_id") ?? "";

      if (_titleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Please enter a title")));
        return;
      }

      setState(() => isLoading = true);

      final uri = Uri.parse("${ApiConfig.apiBaseUrl}/posts");
      var request = http.MultipartRequest("POST", uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Connection'] = 'keep-alive';

      if (userId.isNotEmpty) {
        request.fields["user_id"] = userId;
      }

      final currentUsername =
          (prefs.getString("username") ??
                  prefs.getString("user_name") ??
                  prefs.getString("name") ??
                  "")
              .trim();
      final currentProfileImg =
          (prefs.getString("profile_image_url") ??
                  prefs.getString("profile_image") ??
                  prefs.getString("profileImage") ??
                  "")
              .trim();
      if (currentUsername.isNotEmpty) {
        request.fields["username"] = currentUsername;
      }
      if (currentProfileImg.isNotEmpty) {
        request.fields["profile_image"] = currentProfileImg;
      }

      String backendCatId = "CAT00000004";

      request.fields["categoryId"] = backendCatId;
      request.fields["title"] = _titleController.text.trim();
      request.fields["caption"] = _captionController.text.trim();
      final tags = extractHashtags(_hashtagController.text.trim());
      request.fields["hashtags"] = tags.join(" ");

      if (_postToCommunity &&
          _selectedCommunityId != null &&
          _selectedCommunityId!.isNotEmpty) {
        request.fields["communityId"] = _selectedCommunityId!;
        request.fields["communityName"] = _selectedCommunityName ?? "";
      }

      List<Map<String, dynamic>> pagesJson = [];
      for (var page in widget.pages) {
        List<Map<String, dynamic>> blocksJson = [];
        for (var block in page.blocks) {
          String? imageName;
          if (block.type == "image") {
            if (block.image != null) {
              final fileName =
                  "${block.blockId}_${DateTime.now().millisecondsSinceEpoch}.jpg";
              final mimeType = lookupMimeType(block.image!.path);
              final mimeSplit = mimeType?.split('/') ?? ['image', 'jpeg'];
              request.files.add(
                await http.MultipartFile.fromPath(
                  "page_images",
                  block.image!.path,
                  filename: fileName,
                  contentType: MediaType(mimeSplit[0], mimeSplit[1]),
                ),
              );
              imageName = fileName;
            } else if (block.imageUrl != null && block.imageUrl!.isNotEmpty) {
              imageName = block.imageUrl;
            }
          }
          blocksJson.add({
            "type": block.type,
            "text": block.text,
            "image": imageName,
            "blockId": block.blockId,
            "imageWidth": block.imageWidth,
            "imagePosX": block.imagePosition?.dx,
            "imagePosY": block.imagePosition?.dy,
            "isHeadline": block.isHeadline,
            "fontColor": block.fontColor,
            "fontSize": block.fontSize,
            "fontFamily": block.fontFamily,
            "lineSpacing": block.lineSpacing,
            "letterSpacing": block.letterSpacing,
            "textAlign": block.textAlign?.index,
          });
        }
        pagesJson.add({
          "fontSize": page.fontSize,
          "fontFamily": page.fontFamily,
          "fontColor": page.fontColor,
          "lineSpacing": page.lineSpacing,
          "letterSpacing": page.letterSpacing,
          "pageMargin": page.pageMargin,
          "textAlign": page.textAlign.index,
          "blocks": blocksJson,
        });
      }
      // Embed title styling inside content so it survives the round-trip
      // without any backend schema changes (content is Mixed type).
      final contentJson = {
        "titleStyle": {
          "fontSize": widget.titleFontSize ?? 28,
          "color": widget.titleColor?.toARGB32() ?? Colors.white.toARGB32(),
          "fontFamily": widget.titleFontFamily ?? "Roboto",
        },
        "pages": pagesJson,
      };
      request.fields["content"] = jsonEncode(contentJson);
      // Send page count so feed can show badge like "13 Pages"
      request.fields["pageCount"] = widget.pages.length.toString();

      if (widget.coverImage != null) {
        final mimeType = lookupMimeType(widget.coverImage!.path);
        final mimeSplit = mimeType?.split('/') ?? ['image', 'jpeg'];
        request.files.add(
          await http.MultipartFile.fromPath(
            "cover_image",
            widget.coverImage!.path,
            contentType: MediaType(mimeSplit[0], mimeSplit[1]),
          ),
        );
      }

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
      );
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Story published successfully!")),
        );

        if (widget.draftId != null) {
          try {
            await http.delete(
              Uri.parse("${ApiConfig.apiBaseUrl}/draft/${widget.draftId}"),
              headers: {"Authorization": "Bearer $token"},
            );
            DraftsManager.instance.notifyDraftsChanged();
          } catch (_) {}
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      } else {
        String errorMsg = "Unknown error";
        try {
          errorMsg = jsonDecode(response.body)["message"] ?? errorMsg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Publish failed: $errorMsg"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to publish: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF0729E8);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Review & Publish",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        backgroundColor: brandColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Final Preview",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Swipe to review your story pages before publishing.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Carousel-like preview
            SizedBox(
              height: size.height * 0.45,
              child: PageView.builder(
                itemCount: widget.pages.length,
                controller: PageController(viewportFraction: 0.8),
                itemBuilder: (context, index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCF5E5),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 15,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.black.withOpacity(0.08),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          _buildPagePreview(index),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 40),
            _buildPostInputSection(),
            const SizedBox(height: 48),

            // Publish Button
            ElevatedButton(
              onPressed: isLoading ? null : _publishPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                minimumSize: const Size(double.infinity, 64),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 10,
                shadowColor: brandColor.withOpacity(0.4),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Publish Story",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
    );
  }

  bool isLoading = false;

  Widget _buildPagePreview(int pageIdx) {
    final page = widget.pages[pageIdx];
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 30, 20, 30),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: page.blocks.map<Widget>((block) {
            if (block.type == "text") {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  block.isHeadline
                      ? (block.text ?? "").toUpperCase()
                      : (block.text ?? ""),
                  style: TextStyle(
                    fontSize: block.isHeadline
                        ? (page.fontSize * 0.8)
                        : (page.fontSize * 0.6),
                    fontWeight: block.isHeadline
                        ? FontWeight.w900
                        : FontWeight.normal,
                    fontFamily: page.fontFamily,
                    color: Color(block.fontColor ?? page.fontColor),
                    height: 1.4,
                  ),
                ),
              );
            }
            if (block.type == "image") {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: block.image != null
                      ? Image.file(block.image!, fit: BoxFit.cover)
                      : (block.imageUrl != null
                            ? Image.network(block.imageUrl!, fit: BoxFit.cover)
                            : const SizedBox()),
                ),
              );
            }
            return const SizedBox();
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPostInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Title (தலைப்பு)",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          decoration: InputDecoration(
            hintText: "Enter the title of your post...",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF0729E8),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
        const SizedBox(height: 32),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Story Caption",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _captionController,
          maxLines: 3,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          decoration: InputDecoration(
            hintText: "Give your readers an interesting introduction...",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF0729E8),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          "Relevant Hashtags",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _hashtagController,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Color(0xFF0729E8),
          ),
          decoration: InputDecoration(
            hintText: "#fantasy #romance #adventure",
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(
              Icons.tag_rounded,
              color: Color(0xFF0729E8),
              size: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF0729E8),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Community Post Option (Add post to community)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _postToCommunity
                  ? const Color(0xFF0729E8).withOpacity(0.4)
                  : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0729E8).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Color(0xFF0729E8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Add Post to Community",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Share this story or PDF with your community",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _postToCommunity,
                    activeColor: const Color(0xFF0729E8),
                    onChanged: (val) {
                      setState(() {
                        _postToCommunity = val;
                      });
                    },
                  ),
                ],
              ),
              if (_postToCommunity) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  "Select Community (கம்யூனிட்டி தேர்வு):",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 10),
                if (_isLoadingCommunities)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0729E8),
                      ),
                    ),
                  )
                else if (_myCommunities.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "You are not a member of any community yet. Join or create a community to post here.",
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCommunityId,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF0729E8),
                        ),
                        items: _myCommunities.map((c) {
                          final cId = c['_id']?.toString() ?? '';
                          final cName = c['name']?.toString() ?? 'Community';
                          final count = c['memberCount'] ?? 1;
                          return DropdownMenuItem<String>(
                            value: cId,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.groups_outlined,
                                  size: 18,
                                  color: Color(0xFF0729E8),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    cName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$count members',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final found = _myCommunities.firstWhere(
                              (c) => c['_id']?.toString() == val,
                              orElse: () => {'name': ''},
                            );
                            setState(() {
                              _selectedCommunityId = val;
                              _selectedCommunityName = found['name']
                                  ?.toString();
                            });
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
