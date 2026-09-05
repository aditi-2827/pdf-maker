import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../theme/app_theme.dart';
import '../utils/file_helper.dart';
import '../services/firestore_service.dart';

enum _ExportFormat { pdf, jpg, png, docx }

class ShareExportScreen extends StatefulWidget {
  final File file;
  const ShareExportScreen({super.key, required this.file});

  @override
  State<ShareExportScreen> createState() => _ShareExportScreenState();
}

class _ShareExportScreenState extends State<ShareExportScreen> {
  _ExportFormat _format = _ExportFormat.pdf;
  bool _compress = false;
  bool _working = false;

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _processExportAndShare() async {
    setState(() => _working = true);
    try {
      String pathToShare = widget.file.path;

      // Handle PDF compression if requested
      if (_format == _ExportFormat.pdf && _compress) {
        final bytes = widget.file.readAsBytesSync();
        final doc = PdfDocument(inputBytes: bytes);
        doc.compressionLevel = PdfCompressionLevel.best;
        doc.fileStructure.incrementalUpdate = false;
        final compressedBytes = doc.saveSync();
        doc.dispose();

        final baseName = widget.file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');
        final compressedFile = await FileHelper.saveBytes(
          compressedBytes,
          '${baseName}_compressed.pdf',
        );
        pathToShare = compressedFile.path;
      } else if (_format == _ExportFormat.jpg || _format == _ExportFormat.png) {
        // Export PDF pages to image
        final pdfxDoc = await pdfx.PdfDocument.openFile(widget.file.path);
        final isPng = _format == _ExportFormat.png;
        final ext = isPng ? 'png' : 'jpg';
        final baseName = widget.file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');

        final List<String> exportedImagePaths = [];

        for (int i = 1; i <= pdfxDoc.pagesCount; i++) {
          final page = await pdfxDoc.getPage(i);
          final pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: isPng ? pdfx.PdfPageImageFormat.png : pdfx.PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
          );
          await page.close();

          if (pageImage != null) {
            final savedImage = await FileHelper.saveBytes(
              pageImage.bytes,
              '${baseName}_page_$i.$ext',
            );
            exportedImagePaths.add(savedImage.path);
          }
        }

        await pdfxDoc.close();

        if (exportedImagePaths.isNotEmpty) {
          pathToShare = exportedImagePaths.first;
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported ${exportedImagePaths.length} image page(s) to app storage.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else if (_format == _ExportFormat.docx) {
        // Extract text & export as TXT/DOCX
        final bytes = widget.file.readAsBytesSync();
        final doc = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(doc);
        final extractedText = extractor.extractText();
        doc.dispose();

        final baseName = widget.file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');
        final txtFile = await FileHelper.saveBytes(
          utf8.encode(extractedText.isNotEmpty ? extractedText : 'No text content found in document.'),
          '${baseName}_extracted.txt',
        );
        pathToShare = txtFile.path;

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Extracted text and created text file!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }

      await FileHelper.shareFile(pathToShare);
      FirestoreService.instance.recordShare(
        widget.file.path.split(Platform.pathSeparator).last,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _formatChip(String label, _ExportFormat value, bool isDark) {
    final selected = _format == value;
    final chipBg = isDark ? AppColors.surface : const Color(0xFFE2E8F0);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _format = value),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.15) : chipBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : (isDark ? Colors.white70 : AppColors.textDark),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _destinationButton(IconData icon, String label, bool isDark) {
    final surfaceColor = isDark ? AppColors.surface : Colors.white;
    final labelColor = isDark ? Colors.white : AppColors.textDark;

    return Expanded(
      child: InkWell(
        onTap: _working ? null : _processExportAndShare,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: surfaceColor,
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: labelColor, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.file.lengthSync();
    final name = widget.file.path.split(Platform.pathSeparator).last;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surface : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textDark;

    return Scaffold(
      appBar: AppBar(title: const Text('Share & Export')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              elevation: isDark ? 0 : 1,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const PdfFileIcon(size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('Size: ${_formatSize(size)}', style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('EXPORT FORMAT', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Row(
              children: [
                _formatChip('PDF', _ExportFormat.pdf, isDark),
                _formatChip('JPG', _ExportFormat.jpg, isDark),
                _formatChip('PNG', _ExportFormat.png, isDark),
                _formatChip('TXT/DOC', _ExportFormat.docx, isDark),
              ],
            ),
            const SizedBox(height: 20),
            if (_format == _ExportFormat.pdf)
              Material(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                elevation: isDark ? 0 : 1,
                child: SwitchListTile(
                  title: Text('Compress Document', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text('Reduce file size for faster email sharing', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                  value: _compress,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _compress = v),
                ),
              ),
            const SizedBox(height: 24),
            Text('SHARE DESTINATION', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                _destinationButton(Icons.email_outlined, 'Email', isDark),
                _destinationButton(Icons.share_outlined, 'AirDrop', isDark),
                _destinationButton(Icons.cloud_outlined, 'Cloud', isDark),
                _destinationButton(Icons.link, 'Link', isDark),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _working ? null : _processExportAndShare,
              icon: _working
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.ios_share),
              label: Text(_working ? 'Exporting...' : 'Export & Share File'),
            ),
          ],
        ),
      ),
    );
  }
}