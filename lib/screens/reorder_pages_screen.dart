import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../theme/app_theme.dart';
import '../utils/file_helper.dart';
import 'document_viewer_screen.dart';

class ReorderPagesScreen extends StatefulWidget {
  final File? initialFile;
  const ReorderPagesScreen({super.key, this.initialFile});

  @override
  State<ReorderPagesScreen> createState() => _ReorderPagesScreenState();
}

class _PageItem {
  final int originalIndex; // index in source PDF (0-based)
  Uint8List? thumbnail;
  bool isLoadingThumb = true;

  _PageItem({required this.originalIndex});
}

class _ReorderPagesScreenState extends State<ReorderPagesScreen> {
  File? _file;
  int _pageCount = 0;
  List<_PageItem> _pages = [];
  bool _isProcessing = false;
  bool _isLoadingThumbs = false;

  pdfx.PdfDocument? _pdfxDoc; // pdfx document for rendering thumbnails

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadFile(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _pdfxDoc?.close();
    super.dispose();
  }

  Future<void> _loadFile(File file) async {
    final doc = PdfDocument(inputBytes: file.readAsBytesSync());
    final count = doc.pages.count;
    doc.dispose();

    await _pdfxDoc?.close();

    final pdfxDoc = await pdfx.PdfDocument.openFile(file.path);

    if (!mounted) return;
    setState(() {
      _file = file;
      _pageCount = count;
      _pages = List.generate(
        count,
        (i) => _PageItem(originalIndex: i),
      );
      _pdfxDoc = pdfxDoc;
      _isLoadingThumbs = true;
    });

    _loadThumbnails(pdfxDoc, count);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      _loadFile(File(result.files.single.path!));
    }
  }

  Future<void> _loadThumbnails(pdfx.PdfDocument pdfxDoc, int count) async {
    for (int i = 0; i < count; i++) {
      if (!mounted) return;
      try {
        final page = await pdfxDoc.getPage(i + 1);
        final pageImage = await page.render(
          width: 120,
          height: 170,
          format: pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        await page.close();

        if (!mounted) return;
        setState(() {
          // Find _PageItem whose originalIndex == i and update it
          for (final p in _pages) {
            if (p.originalIndex == i) {
              p.thumbnail = pageImage?.bytes;
              p.isLoadingThumb = false;
            }
          }
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          for (final p in _pages) {
            if (p.originalIndex == i) {
              p.isLoadingThumb = false;
            }
          }
        });
      }
    }
    if (!mounted) return;
    setState(() => _isLoadingThumbs = false);
  }

  Future<void> _saveReordered() async {
    if (_file == null) return;

    setState(() => _isProcessing = true);
    try {
      final sourceBytes = _file!.readAsBytesSync();

      final outDoc = PdfDocument(); // syncfusion
      outDoc.pages.removeAt(0); // remove default blank page

      for (final item in _pages) {
        final srcDoc = PdfDocument(inputBytes: sourceBytes); // syncfusion
        final template = srcDoc.pages[item.originalIndex].createTemplate();
        final srcSize = srcDoc.pages[item.originalIndex].size;
        final newPage = outDoc.pages.add();
        newPage.graphics.drawPdfTemplate(
          template,
          const Offset(0, 0),
          Size(srcSize.width, srcSize.height),
        );
        srcDoc.dispose();
      }

      final outBytes = outDoc.saveSync();
      outDoc.dispose();

      final baseName = _file!.path
          .split(Platform.pathSeparator)
          .last
          .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');

      final outFile = await FileHelper.saveBytes(
        outBytes,
        '${baseName}_reordered.pdf',
      );

      setState(() => _isProcessing = false);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DocumentViewerScreen(file: outFile)),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder Pages'),
        actions: [
          if (_file != null && !_isProcessing)
            TextButton.icon(
              onPressed: _saveReordered,
              icon: const Icon(Icons.save_alt, size: 18, color: AppColors.primary),
              label: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _file == null ? _buildEmptyState() : _buildPageGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.reorder, color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'Reorder PDF Pages',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pick a PDF and drag pages into any order you want.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textFaint, fontSize: 13.5),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageGrid() {
    return Column(
      children: [
        // Info bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_pageCount pages · Long-press then drag to reorder',
                  style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5),
                ),
              ),
              if (_isLoadingThumbs)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Draggable grid
        Expanded(
          child: _ReorderableGrid(
            pages: _pages,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _pages.removeAt(oldIndex);
                _pages.insert(newIndex, item);
              });
            },
          ),
        ),

        // Bottom bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.swap_horiz, color: Colors.white),
                  label: const Text('Change PDF', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _saveReordered,
                  icon: _isProcessing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_alt),
                  label: Text(_isProcessing ? 'Saving...' : 'Save PDF'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Reorderable Grid Widget ──────────────────────────────────────────────────

class _ReorderableGrid extends StatefulWidget {
  final List<_PageItem> pages;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _ReorderableGrid({
    required this.pages,
    required this.onReorder,
  });

  @override
  State<_ReorderableGrid> createState() => _ReorderableGridState();
}

class _ReorderableGridState extends State<_ReorderableGrid> {
  int? _draggingIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 3;
        const spacing = 10.0;
        const padding = 16.0;
        final itemWidth =
            (constraints.maxWidth - padding * 2 - spacing * (crossAxisCount - 1)) / crossAxisCount;
        final itemHeight = itemWidth * 1.5;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: padding),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: List.generate(widget.pages.length, (index) {
              return _buildDraggableTile(index, itemWidth, itemHeight);
            }),
          ),
        );
      },
    );
  }

  Widget _buildDraggableTile(int index, double width, double height) {
    final item = widget.pages[index];
    final isDragging = _draggingIndex == index;

    return DragTarget<int>(
      key: ValueKey('target_${item.originalIndex}_$index'),
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) {
        widget.onReorder(details.data, index);
        setState(() => _draggingIndex = null);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return LongPressDraggable<int>(
          data: index,
          onDragStarted: () => setState(() => _draggingIndex = index),
          onDragEnd: (_) => setState(() => _draggingIndex = null),
          onDraggableCanceled: (vel, offset) => setState(() => _draggingIndex = null),
          feedback: _PageTile(
            item: item,
            width: width,
            height: height,
            pageNumber: index + 1,
            isDragging: true,
            isHovered: false,
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _PageTile(
              item: item,
              width: width,
              height: height,
              pageNumber: index + 1,
              isDragging: false,
              isHovered: false,
            ),
          ),
          child: AnimatedOpacity(
            opacity: isDragging ? 0.3 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: _PageTile(
              item: item,
              width: width,
              height: height,
              pageNumber: index + 1,
              isDragging: false,
              isHovered: isHovered,
            ),
          ),
        );
      },
    );
  }
}

class _PageTile extends StatelessWidget {
  final _PageItem item;
  final double width;
  final double height;
  final int pageNumber;
  final bool isDragging;
  final bool isHovered;

  const _PageTile({
    required this.item,
    required this.width,
    required this.height,
    required this.pageNumber,
    required this.isDragging,
    required this.isHovered,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: width,
      height: height + 28,
      decoration: BoxDecoration(
        color: isHovered ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHovered ? AppColors.primary : AppColors.divider.withValues(alpha: 0.15),
          width: isHovered ? 2 : 1,
        ),
        boxShadow: isDragging
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))]
            : [],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: item.isLoadingThumb
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : item.thumbnail != null
                      ? Image.memory(
                          item.thumbnail!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : const Center(child: Icon(Icons.description, color: AppColors.primary, size: 32)),
            ),
          ),
          Container(
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: Text(
              'Page $pageNumber',
              style: const TextStyle(
                color: AppColors.textFaint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
