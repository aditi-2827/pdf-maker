import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../theme/app_theme.dart';
import '../utils/file_helper.dart';
import 'document_viewer_screen.dart';

class ScanReviewScreen extends StatefulWidget {
  final List<File> pages;
  const ScanReviewScreen({super.key, required this.pages});

  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  late List<File> _pages;
  late List<int> _rotations; // degrees per page
  int _index = 0;
  bool _saving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pages = List.of(widget.pages);
    _rotations = List.filled(_pages.length, 0);
  }

  // ── Page operations ─────────────────────────────────────────────────────────

  void _rotate() => setState(() => _rotations[_index] = (_rotations[_index] + 90) % 360);

  void _deletePage() {
    if (_pages.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _pages.removeAt(_index);
      _rotations.removeAt(_index);
      if (_index >= _pages.length) _index = _pages.length - 1;
    });
  }

  Future<void> _retake() async {
    final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (shot != null) {
      setState(() {
        _pages[_index] = File(shot.path);
        _rotations[_index] = 0;
      });
    }
  }

  Future<void> _addPage() async {
    final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (shot != null) {
      setState(() {
        _pages.add(File(shot.path));
        _rotations.add(0);
        _index = _pages.length - 1;
      });
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _saveAsPdf() async {
    setState(() => _saving = true);
    try {
      final pdf = pw.Document();
      for (int i = 0; i < _pages.length; i++) {
        var bytes = await _pages[i].readAsBytes();
        final rotation = _rotations[i];
        if (rotation != 0) {
          final decoded = img.decodeImage(bytes);
          if (decoded != null) {
            final rotated = img.copyRotate(decoded, angle: rotation);
            bytes = img.encodeJpg(rotated);
          }
        }
        final image = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(0),
            build: (ctx) => pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        );
      }

      final outBytes = await pdf.save();
      final outFile = await FileHelper.saveBytes(
        outBytes,
        'Scan_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      setState(() => _saving = false);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DocumentViewerScreen(file: outFile)),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving PDF: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Review · Page ${_index + 1} of ${_pages.length}'),
        actions: [
          if (_pages.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              tooltip: 'Delete this page',
              onPressed: _deletePage,
            ),
          TextButton.icon(
            onPressed: _addPage,
            icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
            label: const Text('Add Page', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Page thumbnail carousel ─────────────────────────────────────
          if (_pages.length > 1)
            Container(
              height: 70,
              color: isDark ? AppColors.bg : const Color(0xFFF4F6FB),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _pages.length,
                itemBuilder: (context, i) {
                  final isSelected = i == _index;
                  return GestureDetector(
                    onTap: () => setState(() => _index = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      width: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 6)]
                            : [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Transform.rotate(
                          angle: _rotations[i] * 3.14159 / 180,
                          child: Image.file(_pages[i], fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // ── Main image preview ──────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.white,
                  width: double.infinity,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Transform.rotate(
                      key: ValueKey('$_index-${_rotations[_index]}'),
                      angle: _rotations[_index] * 3.14159 / 180,
                      child: Image.file(_pages[_index], fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Tool bar ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ToolButton(icon: Icons.rotate_right, label: 'Rotate', onTap: _rotate),
                _ToolButton(icon: Icons.refresh, label: 'Retake', onTap: _retake),
                _ToolButton(icon: Icons.navigate_before, label: 'Prev',
                    onTap: _index > 0 ? () => setState(() => _index--) : null),
                _ToolButton(icon: Icons.navigate_next, label: 'Next',
                    onTap: _index < _pages.length - 1 ? () => setState(() => _index++) : null),
              ],
            ),
          ),

          // ── Save button ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveAsPdf,
                icon: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_saving ? 'Saving...' : 'Save as PDF (${_pages.length} page${_pages.length > 1 ? 's' : ''})'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tool button ─────────────────────────────────────────────────────────────

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ToolButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: enabled ? AppColors.primary : Colors.grey, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? AppColors.textFaint : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}