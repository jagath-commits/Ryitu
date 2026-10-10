import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/reading_page.dart';

class PdfUploadPage extends StatefulWidget {
  final String? communityId;
  final String? communityName;

  const PdfUploadPage({
    super.key,
    this.communityId,
    this.communityName,
  });

  @override
  State<PdfUploadPage> createState() => _PdfUploadPageState();
}

class _PdfUploadPageState extends State<PdfUploadPage> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _selectedPdfFile;
  String? _pdfFileName;
  int _pdfFileSize = 0;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    setState(() => _errorMessage = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        final name = result.files.single.name;
        final size = result.files.single.size;

        if (path == null) return;

        // Validation: Must be .pdf
        if (!name.toLowerCase().endsWith('.pdf')) {
          setState(() {
            _errorMessage = 'Invalid file format. Only PDF files are supported.';
          });
          return;
        }

        // Validation: Max 50MB
        if (size > 50 * 1024 * 1024) {
          setState(() {
            _errorMessage = 'File too large. Maximum PDF size is 50 MB.';
          });
          return;
        }

        setState(() {
          _selectedPdfFile = File(path);
          _pdfFileName = name;
          _pdfFileSize = size;
          if (_titleController.text.trim().isEmpty) {
            _titleController.text = name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '').replaceAll(RegExp(r'[-_]'), ' ');
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to pick file: $e';
      });
    }
  }

  Future<void> _uploadPdf() async {
    if (_selectedPdfFile == null) {
      setState(() => _errorMessage = 'Please select a PDF document first.');
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please provide a book title.');
      return;
    }

    final author = _authorController.text.trim().isNotEmpty
        ? _authorController.text.trim()
        : 'Unknown Author';
    final description = _descriptionController.text.trim();

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.2;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final userId = prefs.getString('user_id') ?? 'USR00000001';

      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/books/upload');
      final request = http.MultipartRequest('POST', uri);

      if (token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['title'] = title;
      request.fields['author'] = author;
      request.fields['description'] = description;
      request.fields['userId'] = userId;
      request.fields['user_id'] = userId;

      if (widget.communityId != null && widget.communityId!.isNotEmpty) {
        request.fields['communityId'] = widget.communityId!;
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'pdf',
          _selectedPdfFile!.path,
          filename: _pdfFileName ?? 'document.pdf',
          contentType: MediaType('application', 'pdf'),
        ),
      );

      setState(() => _uploadProgress = 0.5);

      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      setState(() => _uploadProgress = 0.85);

      final response = await http.Response.fromStream(streamedResponse);
      setState(() => _uploadProgress = 1.0);

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          final book = decoded['data']?['book'];
          final bookId = book?['_id'] ?? '';
          final pageCount = int.tryParse(book?['pageCount']?.toString() ?? '1') ?? 1;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Book uploaded successfully! Opening reader...'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ReadingPage(
                bookId: bookId.toString(),
                bookTitle: title,
                author: author,
                totalPages: pageCount,
                communityId: widget.communityId,
              ),
            ),
          );
          return;
        }
      }

      final errorMsg = jsonDecode(response.body)['message'] ?? 'Upload failed (${response.statusCode})';
      setState(() {
        _isUploading = false;
        _errorMessage = errorMsg;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _errorMessage = 'Upload failed: $e. Please check your network and retry.';
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.communityName != null ? 'Upload PDF to ${widget.communityName}' : 'Upload PDF Book'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PDF Picker Card
            GestureDetector(
              onTap: _isUploading ? null : _pickPdfFile,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.brand.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedPdfFile != null ? AppColors.brand : AppColors.brand.withOpacity(0.3),
                    width: _selectedPdfFile != null ? 2 : 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedPdfFile != null ? Icons.picture_as_pdf_rounded : Icons.upload_file_rounded,
                        size: 40,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _selectedPdfFile != null ? _pdfFileName! : 'Tap to select PDF file',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedPdfFile != null
                          ? _formatFileSize(_pdfFileSize)
                          : 'Supports standard PDF files up to 50 MB',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (_selectedPdfFile != null) ...[
                      const SizedBox(height: 12),
                      Chip(
                        label: const Text('Change File'),
                        avatar: const Icon(Icons.edit_rounded, size: 16),
                        backgroundColor: Colors.white,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Metadata Form
            const Text(
              'Book Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Book Title *',
                hintText: 'Enter title of the book',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _authorController,
              decoration: const InputDecoration(
                labelText: 'Author Name',
                hintText: 'e.g. Kalki Krishnamurthy, Donald Knuth',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Brief summary or chapter overview...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // Error Display & Retry State
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Upload Progress Bar
            if (_isUploading) ...[
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: Colors.grey.shade200,
                color: AppColors.brand,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Uploading & processing pages... ${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit / Retry Button
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadPdf,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(_errorMessage != null ? 'Retry Upload' : 'Upload & Read Book'),
            ),
          ],
        ),
      ),
    );
  }
}
