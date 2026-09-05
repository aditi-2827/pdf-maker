import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../theme/app_theme.dart';
import '../utils/file_helper.dart';
import 'document_viewer_screen.dart';

// Rotation in degrees — stored per-page, applied on save
enum _Rotation { r0, r90, r180, r270 }

extension _RotExt on _Rotation {
  _Rotation get next => _Rotation.values[(index + 1) % 4];
  PdfPageRotateAngle get syncAngle => [
        PdfPageRotateAngle.rotateAngle0,
        PdfPageRotateAngle.rotateAngle90,
        PdfPageRotateAngle.rotateAngle180,
        PdfPageRotateAngle.rotateAngle270,
      ][index];
  String get label => ['0°', '90°', '180°', '270°'][index];
}

class _RotatePage {
  final int index; // 0-based
  _Rotation rotation = _Rotation.r0;
  Uint8List? thumbnail;
  bool isLoadingThumb = true;

  _RotatePage({required this.index});
}

class RotatePagesScreen extends StatefulWidget {
  final File? initialFile;
  const RotatePagesScreen({super.key, this.initialFile});

  @override
  State<RotatePagesScreen> createState() => _RotatePagesScreenState();
}

class _RotatePagesScreenState extends State<RotatePagesScreen> {
  File? _file;
  List<_RotatePage> _pages = [];
  bool _isProcessing = false;
  bool _isLoadingThumbs = false;
  bool _applyToAll = false;

  pdfx.PdfDocument? _pdfxDoc;

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
      _pages = List.generate(count, (i) => _RotatePage(index: i));
      _pdfxDoc = pdfxDoc;
      _isLoadingThumbs = true;
      _applyToAll = false;
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
          _pages[i].thumbnail = pageImage?.bytes;
          _pages[i].isLoadingThumb = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _pages[i].isLoadingThumb = false);
      }
    }
    if (!mounted) return;
    setState(() => _isLoadingThumbs = false);
  }

  void _rotatePage(int index) {
    setState(() {
      if (_applyToAll) {
        final next = _pages[index].rotation.next;
        for (final p in _pages) {
          p.rotation = next;
        }
      } else {
        _pages[index].rotation = _pages[index].rotation.next;
      }
    });
  }

  void _rotateAll(int quarterTurns) {
    setState(() {
      for (final p in _pages) {
        final newIndex = (p.rotation.index + quarterTurns) % 4;
        p.rotation = _Rotation.values[newIndex];
      }
    });
  }

  Future<void> _saveRotated() async {
    if (_file == null) return;

    // Check if anything was actually rotated
    final anyRotated = _pages.any((p) => p.rotation != _Rotation.r0);
    if (!anyRotated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rotation applied. Tap a page thumbnail to rotate it.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final bytes = _file!.readAsBytesSync();
      final doc = PdfDocument(inputBytes: bytes); // syncfusion

      for (final item in _pages) {
        if (item.rotation != _Rotation.r0) {
          doc.pages[item.index].rotation = item.rotation.syncAngle;
        }
      }

      final outBytes = doc.saveSync();
      doc.dispose();

      final baseName = _file!.path
          .split(Platform.pathSeparator)
          .last
          .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');

      final outFile = await FileHelper.saveBytes(outBytes, '${baseName}_rotated.pdf');

      setState(() => _isProcessing = false);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DocumentViewerScreen(file: outFile)),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rotate Pages'),
        actions: [
          if (_file != null)
            TextButton.icon(
              onPressed: _isProcessing ? null : _saveRotated,
              icon: const Icon(Icons.save_alt, size: 18, color: AppColors.primary),
              label: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _file == null ? _buildEmptyState() : _buildBody(),
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.rotate_right, color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              'Rotate PDF Pages',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rotate individual pages or all pages at once.',
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

  Widget _buildBody() {
    return Column(
      children: [
        // Controls bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text('Rotate All:', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 10),
                  _RotBtn(
                    icon: Icons.rotate_left,
                    label: '-90°',
                    onTap: () => _rotateAll(3),
                  ),
                  const SizedBox(width: 8),
                  _RotBtn(
                    icon: Icons.rotate_right,
                    label: '+90°',
                    onTap: () => _rotateAll(1),
                  ),
                  const SizedBox(width: 8),
                  _RotBtn(
                    icon: Icons.flip,
                    label: '180°',
                    onTap: () => _rotateAll(2),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.textFaint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tap any page thumbnail to rotate it · ${_pages.length} pages',
                      style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5),
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
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Apply tap rotation to all pages',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12),
                ),
                value: _applyToAll,
                onChanged: (v) => setState(() => _applyToAll = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Page grid
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const crossAxisCount = 3;
              const spacing = 10.0;
              const padding = 16.0;
              final itemWidth = (constraints.maxWidth - padding * 2 - spacing * (crossAxisCount - 1)) / crossAxisCount;
              final itemHeight = itemWidth * 1.5;

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: padding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: itemWidth / (itemHeight + 44),
                ),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return GestureDetector(
                    onTap: () => _rotatePage(index),
                    child: _RotatePageTile(
                      page: page,
                      pageNumber: index + 1,
                      itemHeight: itemHeight,
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Bottom buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change PDF'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _saveRotated,
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

// ─── Small helper widgets ─────────────────────────────────────────────────────

class _RotBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RotBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: scheme.onSurface, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _RotatePageTile extends StatelessWidget {
  final _RotatePage page;
  final int pageNumber;
  final double itemHeight;

  const _RotatePageTile({
    required this.page,
    required this.pageNumber,
    required this.itemHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isRotated = page.rotation != _Rotation.r0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRotated ? AppColors.primary : AppColors.divider.withValues(alpha: 0.15),
          width: isRotated ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedRotation(
                    turns: page.rotation.index * 0.25,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: page.isLoadingThumb
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : page.thumbnail != null
                            ? Image.memory(page.thumbnail!, fit: BoxFit.cover, width: double.infinity)
                            : const Center(child: Icon(Icons.description, color: AppColors.primary, size: 32)),
                  ),
                  // Tap hint overlay
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.rotate_right, size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Page $pageNumber',
                  style: const TextStyle(color: AppColors.textFaint, fontSize: 10, fontWeight: FontWeight.w600),
                ),
                if (isRotated)
                  Text(
                    page.rotation.label,
                    style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
