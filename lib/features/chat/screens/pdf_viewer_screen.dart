import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:internet_file/internet_file.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/utils/downloader.dart';
import '../../../core/utils/app_localizations.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfSource; // data URI hoặc URL
  final String? fileName;

  const PdfViewerScreen({
    super.key,
    required this.pdfSource,
    this.fileName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;
  int _totalPages = 0;
  int _currentPage = 1;

  String get _resolvedUrl {
    final src = widget.pdfSource;
    if (src.startsWith('data:')) {
      return src;
    }
    return AppConfig.resolveMediaUrl(src);
  }

  bool get _isBase64DataUri => widget.pdfSource.startsWith('data:');

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<PdfDocument> _loadPdfDocument() async {
    if (_isBase64DataUri) {
      // Base64 data - decode and create from bytes
      final base64Str = widget.pdfSource.split(',').last;
      final bytes = base64Decode(base64Str);
      return await PdfDocument.openData(bytes);
    } else {
      // URL - load from network using internet_file
      final url = _resolvedUrl;
      final pdfData = await InternetFile.get(url);
      return await PdfDocument.openData(pdfData);
    }
  }

  Future<void> _initPdf() async {
    try {
      final document = await _loadPdfDocument();
      if (mounted) {
        setState(() {
          _pdfController = PdfControllerPinch(document: Future.value(document));
          _totalPages = document.pagesCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _downloadPdf() async {
    if (_isBase64DataUri) {
      downloadDataUri(widget.pdfSource, widget.fileName ?? 'document.pdf');
    } else {
      downloadDataUri(widget.pdfSource, widget.fileName ?? 'document.pdf');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).translate('downloading'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName ?? 'PDF Viewer'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$_currentPage/$_totalPages',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: AppLocalizations.of(context).translate('download'),
            onPressed: _downloadPdf,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_pdfController != null)
            PdfViewPinch(
              controller: _pdfController!,
              onPageChanged: (page) {
                if (mounted) {
                  setState(() {
                    _currentPage = page;
                  });
                }
              },
              builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                options: const DefaultBuilderOptions(),
                documentLoaderBuilder: (_) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text('Đang tải tài liệu...', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                pageLoaderBuilder: (_) => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                errorBuilder: (_, error) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Lỗi khi tải trang', style: TextStyle(color: AppColors.error, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
          if (_isLoading && _pdfController == null)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Đang tải tài liệu...', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('Không thể tải tài liệu', style: TextStyle(color: AppColors.error, fontSize: 16)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
