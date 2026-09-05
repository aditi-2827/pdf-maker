import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../theme/app_theme.dart';
import '../utils/file_helper.dart';
import 'document_viewer_screen.dart';

class _MergeItem {
  final File file;
  final int pageCount;
  _MergeItem(this.file, this.pageCount);
}

class MergeDocumentsScreen extends StatefulWidget {
  const MergeDocumentsScreen({super.key});

  @override
  State<MergeDocumentsScreen> createState() => _MergeDocumentsScreenState();
}

class _MergeDocumentsScreenState extends State<MergeDocumentsScreen> {
  final List<_MergeItem> _items = [];
  bool _isMerging = false;

  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null) return;

    for (final path in result.paths.whereType<String>()) {
      final file = File(path);
      final doc = PdfDocument(inputBytes: file.readAsBytesSync());
      final count = doc.pages.count;
      doc.dispose();
      setState(() => _items.add(_MergeItem(file, count)));
    }
  }

  Future<void> _mergeFiles() async {
    if (_items.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 PDF files to merge.')),
      );
      return;
    }

    setState(() => _isMerging = true);
    try {
      final PdfDocument mergedDocument = PdfDocument();
      mergedDocument.pages.removeAt(0);

      for (final item in _items) {
        final source = PdfDocument(inputBytes: item.file.readAsBytesSync());
        for (int i = 0; i < source.pages.count; i++) {
          final template = source.pages[i].createTemplate();
          final newPage = mergedDocument.pages.add();
          newPage.graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            Size(newPage.size.width, newPage.size.height),
          );
        }
        source.dispose();
      }

      final bytes = mergedDocument.saveSync();
      mergedDocument.dispose();

      final outFile = await FileHelper.saveBytes(
        bytes,
        'Merged_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      setState(() => _isMerging = false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DocumentViewerScreen(file: outFile)),
      );
    } catch (e) {
      setState(() => _isMerging = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error merging files: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge Documents')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Drag rows to reorder PDF compilation sequence',
              style: TextStyle(color: AppColors.textFaint, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('No files added yet', style: TextStyle(color: AppColors.textFaint)))
                  : ReorderableListView.builder(
                itemCount: _items.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final item = _items.removeAt(oldIndex);
                    _items.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    key: ValueKey(item.file.path + index.toString()),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            const Icon(Icons.drag_handle, color: AppColors.textFaint),
                            const SizedBox(width: 8),
                            const PdfFileIcon(size: 38),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.file.path.split(Platform.pathSeparator).last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 13.5),
                                  ),
                                  Text('${item.pageCount} pages', style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              onPressed: () => setState(() => _items.removeAt(index)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _addFiles,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add More Files', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: AppColors.divider, style: BorderStyle.solid),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _isMerging ? null : _mergeFiles,
              icon: _isMerging
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.call_merge),
              label: Text(_isMerging ? 'Merging...' : 'Merge ${_items.length} PDFs'),
            ),
          ],
        ),
      ),
    );
  }
}