import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../utils/file_helper.dart';

class SplitScreen extends StatefulWidget {
  final File? initialFile;
  const SplitScreen({super.key, this.initialFile});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  File? _file;
  int _pageCount = 0;
  bool _isProcessing = false;
  bool _splitEveryPage = true;

  final _startController = TextEditingController();
  final _endController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadFile(widget.initialFile!);
    }
  }

  void _loadFile(File file) {
    final doc = PdfDocument(
      inputBytes: file.readAsBytesSync(),
    );
    final count = doc.pages.count;
    doc.dispose();

    setState(() {
      _file = file;
      _pageCount = count;
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

  Future<void> _splitFile() async {
    if (_file == null) {
      _showMessage('Please select a PDF first.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final bytes = await _file!.readAsBytes();

      final fileName = _file!.path
          .split(Platform.pathSeparator)
          .last;

      final baseName = fileName.replaceFirst(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );

      final List<String> outputPaths = [];

      if (_splitEveryPage) {
        for (int i = 0; i < _pageCount; i++) {
          final doc = PdfDocument(
            inputBytes: bytes,
          );

          // Remove all pages except page i.
          for (int p = doc.pages.count - 1; p >= 0; p--) {
            if (p != i) {
              doc.pages.removeAt(p);
            }
          }

          final outBytes = doc.saveSync();

          doc.dispose();

          final outFile = await FileHelper.saveBytes(
            outBytes,
            '${baseName}_page${i + 1}.pdf',
          );

          outputPaths.add(outFile.path);
        }
      } else {
        final start =
            int.tryParse(_startController.text) ?? 1;

        final end =
            int.tryParse(_endController.text) ?? _pageCount;

        if (start < 1 ||
            end > _pageCount ||
            start > end) {
          _showMessage(
            'Invalid page range. Document has $_pageCount pages.',
          );

          setState(() => _isProcessing = false);

          return;
        }

        final doc = PdfDocument(
          inputBytes: bytes,
        );

        for (int p = doc.pages.count - 1; p >= 0; p--) {
          if (p < start - 1 || p > end - 1) {
            doc.pages.removeAt(p);
          }
        }

        final outBytes = doc.saveSync();

        doc.dispose();

        final outFile = await FileHelper.saveBytes(
          outBytes,
          '${baseName}_p$start-$end.pdf',
        );

        outputPaths.add(outFile.path);
      }

      if (!mounted) return;

      setState(() => _isProcessing = false);

      _showResultDialog(outputPaths);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isProcessing = false);

      _showMessage(
        'Error splitting file: $e',
      );
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
      ),
    );
  }

  void _showResultDialog(List<String> paths) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Split complete'),
        content: Text(
          '${paths.length} file(s) created in PdfMaker folder.',
        ),
        actions: [
          if (paths.length == 1)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                FileHelper.openFile(paths.first);
              },
              child: const Text('Open'),
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
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _file == null
                    ? 'Select PDF file'
                    : _file!.path
                    .split(Platform.pathSeparator)
                    .last,
              ),
            ),

            if (_file != null) ...[
              const SizedBox(height: 8),

              Text(
                '$_pageCount pages found',
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 20),

              SwitchListTile(
                title: const Text(
                  'Split every page into its own PDF',
                ),
                value: _splitEveryPage,
                onChanged: (v) {
                  setState(() {
                    _splitEveryPage = v;
                  });
                },
              ),

              if (!_splitEveryPage) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startController,
                        keyboardType:
                        TextInputType.number,
                        decoration:
                        const InputDecoration(
                          labelText: 'Start page',
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: TextField(
                        controller: _endController,
                        keyboardType:
                        TextInputType.number,
                        decoration:
                        const InputDecoration(
                          labelText: 'End page',
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed:
                _isProcessing ? null : _splitFile,
                icon: _isProcessing
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.call_split,
                ),
                label: Text(
                  _isProcessing
                      ? 'Splitting...'
                      : 'Split PDF',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}