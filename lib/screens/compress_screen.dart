import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../utils/file_helper.dart';

enum CompressLevel { low, medium, high }

class CompressScreen extends StatefulWidget {
  final File? initialFile;
  const CompressScreen({super.key, this.initialFile});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  File? _file;
  int _originalSize = 0;
  bool _isProcessing = false;
  CompressLevel _level = CompressLevel.medium;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadFile(widget.initialFile!);
    }
  }

  void _loadFile(File file) {
    setState(() {
      _file = file;
      _originalSize = file.lengthSync();
    });
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

  PdfCompressionLevel _mapLevel() {
    switch (_level) {
      case CompressLevel.low:
        return PdfCompressionLevel.normal;
      case CompressLevel.medium:
        return PdfCompressionLevel.aboveNormal;
      case CompressLevel.high:
        return PdfCompressionLevel.best;
    }
  }

  Future<void> _compressFile() async {
    if (_file == null) {
      _showMessage('Please select a PDF first.');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final bytes = _file!.readAsBytesSync();
      final doc = PdfDocument(inputBytes: bytes);

      // Apply compression settings
      doc.compressionLevel = _mapLevel();
      doc.fileStructure.incrementalUpdate = false;

      final outBytes = doc.saveSync();
      doc.dispose();

      final baseName = _file!.path.split('/').last.replaceAll('.pdf', '');
      final outFile = await FileHelper.saveBytes(
        outBytes,
        '${baseName}_compressed.pdf',
      );

      setState(() => _isProcessing = false);
      _showResultDialog(outFile.path, outBytes.length);
    } catch (e) {
      setState(() => _isProcessing = false);
      _showMessage('Error compressing file: $e');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  void _showResultDialog(String path, int newSize) {
    final saved = _originalSize - newSize;
    final pct = _originalSize > 0 ? (saved / _originalSize * 100).toStringAsFixed(1) : '0';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Compression complete'),
        content: Text(
          'Original: ${_formatSize(_originalSize)}\n'
              'Compressed: ${_formatSize(newSize)}\n'
              'Saved: $pct%',
        ),
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
      appBar: AppBar(title: const Text('Compress PDF')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(_file == null ? 'Select PDF file' : _file!.path.split('/').last),
            ),
            if (_file != null) ...[
              const SizedBox(height: 8),
              Text(
                'Original size: ${_formatSize(_originalSize)}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              const Text('Compression level', style: TextStyle(fontWeight: FontWeight.w600)),
              RadioListTile<CompressLevel>(
                title: const Text('Low (best quality)'),
                value: CompressLevel.low,
                groupValue: _level,
                onChanged: (v) => setState(() => _level = v!),
              ),
              RadioListTile<CompressLevel>(
                title: const Text('Medium (recommended)'),
                value: CompressLevel.medium,
                groupValue: _level,
                onChanged: (v) => setState(() => _level = v!),
              ),
              RadioListTile<CompressLevel>(
                title: const Text('High (smallest size)'),
                value: CompressLevel.high,
                groupValue: _level,
                onChanged: (v) => setState(() => _level = v!),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isProcessing ? null : _compressFile,
                icon: _isProcessing
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.compress),
                label: Text(_isProcessing ? 'Compressing...' : 'Compress PDF'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}