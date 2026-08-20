import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/file_helper.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<File> _images = [];
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImages() async {
    final result = await _picker.pickMultiImage();
    if (result.isNotEmpty) {
      setState(() {
        _images.addAll(result.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _convertToPdf() async {
    if (_images.isEmpty) {
      _showMessage('Please select at least 1 image.');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final pdf = pw.Document();

      for (final imageFile in _images) {
        final bytes = await imageFile.readAsBytes();
        final image = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) => pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        );
      }

      final bytes = await pdf.save();
      final outFile = await FileHelper.saveBytes(
        bytes,
        'images_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      setState(() => _isProcessing = false);
      _showResultDialog(outFile.path);
    } catch (e) {
      setState(() => _isProcessing = false);
      _showMessage('Error creating PDF: $e');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showResultDialog(String path) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('PDF created'),
        content: Text('Saved to:\n$path'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FileHelper.openFile(path);
            },
            child: const Text('Open'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FileHelper.shareFile(path);
            },
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image to PDF')),
      body: Column(
        children: [
          Expanded(
            child: _images.isEmpty
                ? const Center(child: Text('No images selected yet'))
                : ReorderableGridView(
              images: _images,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  final item = _images.removeAt(oldIndex);
                  _images.insert(newIndex, item);
                });
              },
              onRemove: (index) => setState(() => _images.removeAt(index)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add images'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isProcessing ? null : _convertToPdf,
                    icon: _isProcessing
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(_isProcessing ? 'Converting...' : 'Convert to PDF'),
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

/// Simple reorderable grid for image thumbnails with remove buttons.
class ReorderableGridView extends StatelessWidget {
  final List<File> images;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onRemove;

  const ReorderableGridView({
    super.key,
    required this.images,
    required this.onReorder,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(images[index], fit: BoxFit.cover),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => onRemove(index),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
            Positioned(
              bottom: 2,
              left: 2,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
