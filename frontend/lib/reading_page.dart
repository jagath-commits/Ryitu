import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/app_theme.dart';

enum ReaderTheme { light, dark, sepia, black }

class ReadingPage extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String author;
  final String? pdfUrl;
  final int initialPage;
  final int totalPages;
  final String? communityId;

  const ReadingPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.author = 'Unknown Author',
    this.pdfUrl,
    this.initialPage = 1,
    this.totalPages = 1,
    this.communityId,
  });

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  late int _currentPage;
  late int _totalPages;
  bool _isLoading = false;

  // Settings: Font Style, Font Size, Font Color, Reading Theme, Zoom
  String _fontStyle = 'Default'; // 'Default', 'Serif', 'Sans', 'Monospace'
  double _fontSize = 18.0; // Small: 14, Medium: 18, Large: 22, Extra Large: 26
  Color _fontColor = const Color(0xFF1A1A1A);
  ReaderTheme _theme = ReaderTheme.light;
  double _zoomScale = 1.0;
  bool _isReflowMode = true; // Reflow extracted text vs Fixed Layout preview

  List<Map<String, dynamic>> _bookmarks = [];
  bool _isBookmarked = false;
  String? _userId;

  // Simulated / extracted text content per page for reflowable mode
  final Map<int, String> _extractedPageTexts = {};
  final Map<int, List<String>> _extractedPageImages = {};

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage > 0 ? widget.initialPage : 1;
    _totalPages = widget.totalPages > 0 ? widget.totalPages : 1;
    _loadUserAndData();
  }

  Future<void> _loadUserAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? 'USR00000001';

    await _fetchProgress();
    await _fetchBookmarks();
    _fetchPageContent(_currentPage);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProgress() async {
    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/books/${widget.bookId}/progress?userId=$_userId');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data']?['progress'] != null) {
          final prog = decoded['data']['progress'];
          final savedPage = int.tryParse(prog['currentPage']?.toString() ?? '1') ?? 1;
          final total = int.tryParse(prog['totalPages']?.toString() ?? '1') ?? _totalPages;
          if (mounted) {
            setState(() {
              _currentPage = savedPage.clamp(1, total);
              _totalPages = total;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/books/${widget.bookId}/progress');
      await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'currentPage': _currentPage,
          'totalPages': _totalPages,
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> _fetchBookmarks() async {
    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/books/${widget.bookId}/bookmarks?userId=$_userId');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data']?['bookmarks'] is List) {
          final list = List<Map<String, dynamic>>.from(decoded['data']['bookmarks']);
          if (mounted) {
            setState(() {
              _bookmarks = list;
              _isBookmarked = _bookmarks.any((b) => b['pageNumber'] == _currentPage);
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleBookmark() async {
    final existing = _bookmarks.firstWhere(
      (b) => b['pageNumber'] == _currentPage,
      orElse: () => {},
    );

    if (existing.isNotEmpty && existing['_id'] != null) {
      // Delete bookmark
      final bookmarkId = existing['_id'];
      try {
        await http.delete(
          Uri.parse('${ApiConfig.apiBaseUrl}/books/${widget.bookId}/bookmarks/$bookmarkId?userId=$_userId'),
        );
        setState(() {
          _bookmarks.removeWhere((b) => b['_id'] == bookmarkId);
          _isBookmarked = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed bookmark for Page $_currentPage')),
          );
        }
      } catch (_) {}
    } else {
      // Add bookmark
      try {
        final res = await http.post(
          Uri.parse('${ApiConfig.apiBaseUrl}/books/${widget.bookId}/bookmarks'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': _userId,
            'pageNumber': _currentPage,
            'note': 'Page $_currentPage bookmark',
          }),
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          final decoded = jsonDecode(res.body);
          final newBm = decoded['data']?['bookmark'];
          if (newBm != null) {
            setState(() {
              _bookmarks.add(Map<String, dynamic>.from(newBm));
              _isBookmarked = true;
            });
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Bookmarked Page $_currentPage')),
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _fetchPageContent(int page) async {
    if (_extractedPageTexts.containsKey(page) || _extractedPageImages.containsKey(page)) return;
    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/books/${widget.bookId}/page/$page');
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final text = decoded['data']['text']?.toString().trim() ?? '';
          final rawImages = decoded['data']['images'];
          List<String> images = [];
          if (rawImages is List) {
            images = rawImages.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
          }

          if (mounted) {
            setState(() {
              if (text.isNotEmpty) {
                _extractedPageTexts[page] = text;
              }
              if (images.isNotEmpty) {
                _extractedPageImages[page] = images;
              }
              if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text) && _fontStyle == 'Default') {
                _fontStyle = 'Mukta Malar';
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() {
      _currentPage = page;
      _isBookmarked = _bookmarks.any((b) => b['pageNumber'] == _currentPage);
    });
    _saveProgress();
    _fetchPageContent(page);
  }

  Color get _themeBgColor {
    switch (_theme) {
      case ReaderTheme.light:
        return const Color(0xFFF9FAFB);
      case ReaderTheme.dark:
        return const Color(0xFF1E293B);
      case ReaderTheme.sepia:
        return const Color(0xFFFBF0D9);
      case ReaderTheme.black:
        return Colors.black;
    }
  }

  Color get _themeTextColor {
    if (_fontColor != const Color(0xFF1A1A1A)) {
      return _fontColor;
    }
    switch (_theme) {
      case ReaderTheme.light:
        return const Color(0xFF1E293B);
      case ReaderTheme.dark:
        return const Color(0xFFF1F5F9);
      case ReaderTheme.sepia:
        return const Color(0xFF453224);
      case ReaderTheme.black:
        return const Color(0xFFE2E8F0);
    }
  }

  String _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    String url = path.trim();

    if (url.startsWith("http://localhost:3001") ||
        url.startsWith("http://127.0.0.1:3001") ||
        url.startsWith("http://localhost:5000") ||
        url.startsWith("http://127.0.0.1:5000")) {
      url = url.replaceFirst(
        RegExp(r'http:\/\/(localhost|127\.0\.0\.1):(3001|5000)'),
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

  TextStyle _getAppliedTextStyle() {
    TextStyle style = TextStyle(
      fontSize: _fontSize,
      color: _themeTextColor,
      height: 1.6,
      letterSpacing: 0.2,
      fontFamilyFallback: const ['Noto Sans Tamil', 'Mukta Malar', 'Roboto'],
    );

    final pageText = _getPageContent(_currentPage);
    final hasTamil = RegExp(r'[\u0B80-\u0BFF]').hasMatch(pageText);
    if (hasTamil && (_fontStyle == 'Default' || _fontStyle == 'Sans' || _fontStyle == 'Sans Serif')) {
      return GoogleFonts.notoSansTamil(textStyle: style);
    }

    switch (_fontStyle) {
      case 'Serif':
        return GoogleFonts.merriweather(textStyle: style);
      case 'Sans':
      case 'Sans Serif':
        return GoogleFonts.inter(textStyle: style);
      case 'Monospace':
        return GoogleFonts.firaCode(textStyle: style);
      case 'Default':
        return style;
      default:
        try {
          return GoogleFonts.getFont(_fontStyle, textStyle: style);
        } catch (_) {
          return style.copyWith(fontFamily: _fontStyle);
        }
    }
  }

  String _getPageContent(int page) {
    if (_extractedPageTexts.containsKey(page)) {
      return _extractedPageTexts[page]!;
    }
    if (_extractedPageImages.containsKey(page) && _extractedPageImages[page]!.isNotEmpty) {
      return '';
    }
    _fetchPageContent(page);
    return 'Reading Page $page...';
  }

  void _showBookmarksModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _themeBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bookmark_rounded, color: AppColors.brand, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Bookmarks (${_bookmarks.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _themeTextColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: _themeTextColor),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              if (_bookmarks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      'No bookmarks added yet.\nTap the bookmark icon on any page to save it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _themeTextColor.withOpacity(0.6)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _bookmarks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final bm = _bookmarks[index];
                      final pageNum = bm['pageNumber'] ?? 1;
                      final note = bm['note'] ?? 'Bookmark';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.brand.withOpacity(0.1),
                          child: Text(
                            '$pageNum',
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          'Page $pageNum',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _themeTextColor,
                          ),
                        ),
                        subtitle: Text(
                          note,
                          style: TextStyle(color: _themeTextColor.withOpacity(0.7)),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final bmId = bm['_id'];
                            if (bmId != null) {
                              await http.delete(
                                Uri.parse('${ApiConfig.apiBaseUrl}/books/${widget.bookId}/bookmarks/$bmId?userId=$_userId'),
                              );
                              setState(() {
                                _bookmarks.removeAt(index);
                                _isBookmarked = _bookmarks.any((b) => b['pageNumber'] == _currentPage);
                              });
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _goToPage(pageNum);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _themeBgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _themeTextColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: AppColors.brand, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Reading Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _themeTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 1. FONT STYLE
                    Text(
                      'Font Style',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _themeTextColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Default',
                        'Roboto',
                        'Lora',
                        'Playfair Display',
                        'Mukta Malar',
                        'Hind Madurai',
                        'Pavanam',
                        'Arima',
                        'Kavivanar',
                        'Catamaran',
                        'Baloo 2',
                        'Tiro Tamil',
                        'Inter',
                        'Merienda',
                        'Lobster',
                        'Serif',
                        'Monospace',
                      ].map((font) {
                        final selected = _fontStyle == font;
                        return ChoiceChip(
                          label: Text(font),
                          selected: selected,
                          selectedColor: AppColors.brand,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : _themeTextColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _fontStyle = font);
                              setModalState(() => _fontStyle = font);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // 2. FONT SIZE
                    Text(
                      'Font Size',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _themeTextColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.text_decrease_rounded),
                          onPressed: () {
                            if (_fontSize > 14) {
                              setState(() => _fontSize -= 2);
                              setModalState(() {});
                            }
                          },
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              _fontSize <= 14
                                  ? 'Small'
                                  : _fontSize <= 18
                                      ? 'Medium'
                                      : _fontSize <= 22
                                          ? 'Large'
                                          : 'Extra Large',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _themeTextColor,
                              ),
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.text_increase_rounded),
                          onPressed: () {
                            if (_fontSize < 28) {
                              setState(() => _fontSize += 2);
                              setModalState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 3. FONT COLOR
                    Text(
                      'Font Color',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _themeTextColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        {'label': 'Default', 'color': const Color(0xFF1A1A1A)},
                        {'label': 'Black', 'color': const Color(0xFF000000)},
                        {'label': 'Red', 'color': const Color(0xFFF44336)},
                        {'label': 'Blue', 'color': const Color(0xFF2196F3)},
                        {'label': 'Green', 'color': const Color(0xFF4CAF50)},
                        {'label': 'Purple', 'color': const Color(0xFF9C27B0)},
                        {'label': 'Orange', 'color': const Color(0xFFFF9800)},
                        {'label': 'Teal', 'color': const Color(0xFF009668)},
                        {'label': 'Brown', 'color': const Color(0xFF795548)},
                        {'label': 'Brand Blue', 'color': const Color(0xFF0729E8)},
                        {'label': 'White', 'color': Colors.white},
                        {'label': 'Sepia', 'color': const Color(0xFF6B4226)},
                      ].map((item) {
                        final c = item['color'] as Color;
                        final label = item['label'] as String;
                        final selected = _fontColor == c;
                        return ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          selectedColor: AppColors.brand,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : _themeTextColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _fontColor = c);
                              setModalState(() => _fontColor = c);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // 4. READING THEMES
                    Text(
                      'Reading Theme',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _themeTextColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildThemeButton('Light', ReaderTheme.light, const Color(0xFFFFFFFF), Colors.black87, setModalState),
                        _buildThemeButton('Sepia', ReaderTheme.sepia, const Color(0xFFFBF0D9), const Color(0xFF423326), setModalState),
                        _buildThemeButton('Dark', ReaderTheme.dark, const Color(0xFF1E293B), Colors.white, setModalState),
                        _buildThemeButton('Black', ReaderTheme.black, Colors.black, Colors.white, setModalState),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 5. ZOOM & VIEW MODE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reflow Text Mode',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _themeTextColor,
                          ),
                        ),
                        Switch(
                          value: _isReflowMode,
                          activeColor: AppColors.brand,
                          onChanged: (val) {
                            setState(() => _isReflowMode = val);
                            setModalState(() {});
                          },
                        ),
                      ],
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

  Widget _buildThemeButton(
    String label,
    ReaderTheme theme,
    Color bg,
    Color fg,
    StateSetter setModalState,
  ) {
    final selected = _theme == theme;
    return GestureDetector(
      onTap: () {
        setState(() => _theme = theme);
        setModalState(() {});
      },
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.brand : Colors.grey.withOpacity(0.3),
                width: selected ? 3 : 1,
              ),
            ),
            child: Center(
              child: Text(
                'Aa',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: _themeTextColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _themeBgColor,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _themeBgColor,
      appBar: AppBar(
        backgroundColor: _themeBgColor,
        elevation: 0,
        foregroundColor: _themeTextColor,
        title: Column(
          children: [
            Text(
              widget.bookTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _themeTextColor,
              ),
            ),
            Text(
              'Page $_currentPage of $_totalPages${_zoomScale > 1.05 ? " • ${(_zoomScale * 100).toInt()}%" : ""}',
              style: TextStyle(
                fontSize: 11,
                color: _themeTextColor.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _isBookmarked ? AppColors.brand : _themeTextColor,
            ),
            tooltip: 'Bookmark Page',
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: 'All Bookmarks',
            onPressed: _showBookmarksModal,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Reading Settings',
            onPressed: _showSettingsModal,
          ),
        ],
      ),
      body: InteractiveViewer(
        scaleEnabled: true,
        panEnabled: true,
        minScale: 0.8,
        maxScale: 3.0,
        onInteractionUpdate: (details) {
          if ((details.scale - _zoomScale).abs() > 0.05) {
            setState(() {
              _zoomScale = details.scale;
            });
          }
        },
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -200) {
                // Swipe left -> Next Page
                if (_currentPage < _totalPages) _goToPage(_currentPage + 1);
              } else if (details.primaryVelocity! > 200) {
                // Swipe right -> Prev Page
                if (_currentPage > 1) _goToPage(_currentPage - 1);
              }
            }
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Book Page Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _theme == ReaderTheme.black
                          ? const Color(0xFF111111)
                          : _theme == ReaderTheme.dark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.author,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _themeTextColor.withOpacity(0.5),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Page $_currentPage',
                                style: const TextStyle(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        if (_extractedPageImages.containsKey(_currentPage) &&
                            _extractedPageImages[_currentPage]!.isNotEmpty) ...[
                          for (final imgUrl in _extractedPageImages[_currentPage]!)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _resolveImageUrl(imgUrl),
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      height: 180,
                                      alignment: Alignment.center,
                                      child: const CircularProgressIndicator(strokeWidth: 2),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                        ],
                        if (_getPageContent(_currentPage).trim().isNotEmpty)
                          Text(
                            _getPageContent(_currentPage),
                            style: _getAppliedTextStyle(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _themeBgColor,
            border: Border(top: BorderSide(color: _themeTextColor.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                color: _currentPage > 1 ? AppColors.brand : Colors.grey,
                onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
              ),
              Expanded(
                child: Slider(
                  value: _currentPage.toDouble(),
                  min: 1,
                  max: _totalPages.toDouble(),
                  divisions: _totalPages > 1 ? _totalPages - 1 : 1,
                  activeColor: AppColors.brand,
                  inactiveColor: AppColors.brand.withOpacity(0.2),
                  onChanged: (val) {
                    _goToPage(val.round());
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                color: _currentPage < _totalPages ? AppColors.brand : Colors.grey,
                onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
