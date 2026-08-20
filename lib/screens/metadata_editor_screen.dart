import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../theme/app_theme.dart';
import '../utils/file_helper.dart';

class MetadataEditorScreen extends StatefulWidget {
  final File? initialFile;
  const MetadataEditorScreen({super.key, this.initialFile});

  @override
  State<MetadataEditorScreen> createState() => _MetadataEditorScreenState();
}

class _MetadataEditorScreenState extends State<MetadataEditorScreen> {
  File? _file;
  bool _isLoading = false;
  bool _isSaving = false;

  // Text controllers for all editable metadata fields
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();
  final _creatorCtrl = TextEditingController();
  final _producerCtrl = TextEditingController();

  // Read-only info
  String _pageCount = '';
  String _fileSize = '';
  String _creationDate = '';
  String _modifyDate = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadFile(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _subjectCtrl.dispose();
    _keywordsCtrl.dispose();
    _creatorCtrl.dispose();
    _producerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFile(File file) async {
    setState(() {
      _file = file;
      _isLoading = true;
    });

    try {
      final bytes = file.readAsBytesSync();
      final doc = PdfDocument(inputBytes: bytes);
      final info = doc.documentInformation;

      if (!mounted) return;
      setState(() {
        _titleCtrl.text = info.title;
        _authorCtrl.text = info.author;
        _subjectCtrl.text = info.subject;
        _keywordsCtrl.text = info.keywords;
        _creatorCtrl.text = info.creator;
        _producerCtrl.text = info.producer;
        _pageCount = '${doc.pages.count} pages';
        _fileSize = _formatSize(file.lengthSync());
        _creationDate = _formatDate(info.creationDate);
        _modifyDate = _formatDate(info.modificationDate);
        _isLoading = false;
      });

      doc.dispose();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Could not read metadata: $e');
    }
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveMetadata() async {
    if (_file == null) return;

    setState(() => _isSaving = true);
    try {
      final bytes = _file!.readAsBytesSync();
      final doc = PdfDocument(inputBytes: bytes);
      final info = doc.documentInformation;

      info.title = _titleCtrl.text.trim();
      info.author = _authorCtrl.text.trim();
      info.subject = _subjectCtrl.text.trim();
      info.keywords = _keywordsCtrl.text.trim();
      info.creator = _creatorCtrl.text.trim();
      info.producer = _producerCtrl.text.trim();

      final outBytes = doc.saveSync();
      doc.dispose();

      final baseName = _file!.path
          .split(Platform.pathSeparator)
          .last
          .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');

      final outFile = await FileHelper.saveBytes(outBytes, '${baseName}_meta.pdf');

      setState(() => _isSaving = false);
      if (!mounted) return;

      _showResultDialog(outFile.path);
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Error saving: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showResultDialog(String path) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 22),
            SizedBox(width: 8),
            Text('Saved!', style: TextStyle(color: Colors.white, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Metadata updated and saved to your PdfMaker folder.',
          style: TextStyle(color: AppColors.textFaint),
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
      appBar: AppBar(
        title: const Text('PDF Metadata Editor'),
        actions: [
          if (_file != null && !_isSaving)
            TextButton.icon(
              onPressed: _saveMetadata,
              icon: const Icon(Icons.save_alt, size: 18, color: AppColors.primary),
              label: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: _file == null
          ? _buildEmptyState()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildForm(),
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
              child: const Icon(Icons.edit_note, color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'PDF Metadata Editor',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'View and edit the title, author, subject and other hidden metadata fields of any PDF.',
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

  Widget _buildForm() {
    final fileName = _file!.path.split(Platform.pathSeparator).last;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // File info card
        _InfoCard(
          fileName: fileName,
          pageCount: _pageCount,
          fileSize: _fileSize,
          creationDate: _creationDate,
          modifyDate: _modifyDate,
          onChangeFile: _pickFile,
        ),
        const SizedBox(height: 20),

        // Editable fields section
        _SectionLabel(label: 'DOCUMENT INFORMATION'),
        const SizedBox(height: 12),
        _MetaField(
          controller: _titleCtrl,
          label: 'Title',
          hint: 'e.g. My Report 2024',
          icon: Icons.title,
        ),
        const SizedBox(height: 12),
        _MetaField(
          controller: _authorCtrl,
          label: 'Author',
          hint: 'e.g. John Smith',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _MetaField(
          controller: _subjectCtrl,
          label: 'Subject',
          hint: 'e.g. Annual Sales Report',
          icon: Icons.label_outline,
        ),
        const SizedBox(height: 12),
        _MetaField(
          controller: _keywordsCtrl,
          label: 'Keywords',
          hint: 'e.g. sales, report, 2024',
          icon: Icons.tag,
        ),
        const SizedBox(height: 20),

        _SectionLabel(label: 'APPLICATION INFO'),
        const SizedBox(height: 12),
        _MetaField(
          controller: _creatorCtrl,
          label: 'Creator Application',
          hint: 'e.g. Microsoft Word',
          icon: Icons.apps,
        ),
        const SizedBox(height: 12),
        _MetaField(
          controller: _producerCtrl,
          label: 'PDF Producer',
          hint: 'e.g. Adobe PDF Library',
          icon: Icons.print_outlined,
        ),
        const SizedBox(height: 28),

        FilledButton.icon(
          onPressed: _isSaving ? null : _saveMetadata,
          icon: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_alt),
          label: Text(_isSaving ? 'Saving...' : 'Save Metadata'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.swap_horiz, color: Colors.white),
          label: const Text('Change File', style: TextStyle(color: Colors.white)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            side: const BorderSide(color: AppColors.divider),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textFaint,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _MetaField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  const _MetaField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.12)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textFaint, fontSize: 13),
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textFaint.withValues(alpha: 0.5), fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String fileName;
  final String pageCount;
  final String fileSize;
  final String creationDate;
  final String modifyDate;
  final VoidCallback onChangeFile;

  const _InfoCard({
    required this.fileName,
    required this.pageCount,
    required this.fileSize,
    required this.creationDate,
    required this.modifyDate,
    required this.onChangeFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onChangeFile,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                const PdfFileIcon(size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$pageCount · $fileSize',
                        style: const TextStyle(color: AppColors.textFaint, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.swap_horiz, color: AppColors.textFaint, size: 18),
              ],
            ),
          ),
          const Divider(color: AppColors.divider, height: 20, thickness: 0.5),
          _InfoRow(label: 'Created', value: creationDate),
          const SizedBox(height: 4),
          _InfoRow(label: 'Modified', value: modifyDate),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
