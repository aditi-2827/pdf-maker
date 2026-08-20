import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../theme/app_theme.dart';
import '../utils/file_helper.dart';

class PdfSecurityScreen extends StatefulWidget {
  final File? initialFile;
  const PdfSecurityScreen({super.key, this.initialFile});

  @override
  State<PdfSecurityScreen> createState() => _PdfSecurityScreenState();
}

class _PdfSecurityScreenState extends State<PdfSecurityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  File? _file;
  bool _isProcessing = false;

  // Encrypt Form
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePass = true;

  // Decrypt Form
  final _decryptPasswordCtrl = TextEditingController();

  // Watermark Form
  final _watermarkTextCtrl = TextEditingController(text: 'CONFIDENTIAL');
  File? _watermarkImageFile;
  double _watermarkOpacity = 0.25;
  Color _watermarkColor = Colors.grey;

  final List<Color> _colorOptions = [
    Colors.grey,
    Colors.red,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialFile != null) {
      _file = widget.initialFile;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _decryptPasswordCtrl.dispose();
    _watermarkTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _file = File(result.files.single.path!));
    }
  }

  Future<void> _pickWatermarkImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _watermarkImageFile = File(picked.path);
      });
    }
  }

  // ── 1. ENCRYPT PDF ──────────────────────────────────────────────────────────
  Future<void> _encryptPdf() async {
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file first.')),
      );
      return;
    }

    final pass = _passwordCtrl.text.trim();
    final confirmPass = _confirmPasswordCtrl.text.trim();

    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password cannot be empty.')),
      );
      return;
    }

    if (pass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final bytes = await _file!.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);

      // Set AES 256-bit password security
      final security = doc.security;
      security.userPassword = pass;
      security.ownerPassword = pass;
      security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;

      final outBytes = doc.saveSync();
      doc.dispose();

      final baseName = _file!.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');
      final outFile = await FileHelper.saveBytes(outBytes, '${baseName}_protected.pdf');

      setState(() => _isProcessing = false);
      if (!mounted) return;

      _showSuccessDialog('PDF Protected Successfully', outFile);
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error encrypting PDF: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  // ── 2. DECRYPT PDF ──────────────────────────────────────────────────────────
  Future<void> _decryptPdf() async {
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file first.')),
      );
      return;
    }

    final pass = _decryptPasswordCtrl.text.trim();
    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the PDF password.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final bytes = await _file!.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes, password: pass);

      // Remove protection by resetting passwords
      doc.security.userPassword = '';
      doc.security.ownerPassword = '';

      final outBytes = doc.saveSync();
      doc.dispose();

      final baseName = _file!.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');
      final outFile = await FileHelper.saveBytes(outBytes, '${baseName}_unlocked.pdf');

      setState(() => _isProcessing = false);
      if (!mounted) return;

      _showSuccessDialog('Password Removed Successfully', outFile);
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect password or unable to decrypt PDF.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // ── 3. ADD WATERMARK ───────────────────────────────────────────────────────
  Future<void> _applyWatermark() async {
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file first.')),
      );
      return;
    }

    final watermarkText = _watermarkTextCtrl.text.trim();
    if (watermarkText.isEmpty && _watermarkImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter watermark text or pick an image.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final bytes = await _file!.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);

      for (int i = 0; i < doc.pages.count; i++) {
        final page = doc.pages[i];
        final pageSize = page.size;

        if (_watermarkImageFile != null) {
          final imgBytes = await _watermarkImageFile!.readAsBytes();
          final pdfImg = PdfBitmap(imgBytes);

          page.graphics.save();
          page.graphics.setTransparency(_watermarkOpacity);

          const w = 220.0;
          final h = (w / pdfImg.width) * pdfImg.height;
          final x = (pageSize.width - w) / 2;
          final y = (pageSize.height - h) / 2;

          page.graphics.drawImage(pdfImg, Rect.fromLTWH(x, y, w, h));
          page.graphics.restore();
        } else {
          final font = PdfStandardFont(PdfFontFamily.helvetica, 46, style: PdfFontStyle.bold);
          final textSize = font.measureString(watermarkText);

          final pdfColor = PdfColor(
            (_watermarkColor.r * 255.0).round().clamp(0, 255),
            (_watermarkColor.g * 255.0).round().clamp(0, 255),
            (_watermarkColor.b * 255.0).round().clamp(0, 255),
          );

          page.graphics.save();
          page.graphics.setTransparency(_watermarkOpacity);

          final cx = pageSize.width / 2;
          final cy = pageSize.height / 2;

          page.graphics.translateTransform(cx, cy);
          page.graphics.rotateTransform(-45);

          page.graphics.drawString(
            watermarkText,
            font,
            brush: PdfSolidBrush(pdfColor),
            bounds: Rect.fromLTWH(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height),
          );

          page.graphics.restore();
        }
      }

      final outBytes = doc.saveSync();
      doc.dispose();

      final baseName = _file!.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');
      final outFile = await FileHelper.saveBytes(outBytes, '${baseName}_watermarked.pdf');

      setState(() => _isProcessing = false);
      if (!mounted) return;

      _showSuccessDialog('Watermark Applied Successfully', outFile);
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding watermark: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _showSuccessDialog(String title, File savedFile) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text('File saved to:\n${savedFile.path}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FileHelper.shareFile(savedFile.path);
            },
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FileHelper.openFile(savedFile.path);
            },
            child: const Text('Open'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _file?.path.split(Platform.pathSeparator).last ?? 'No PDF file selected';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surface : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Security & Watermark'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.textFaint : AppColors.textFaintLight,
          tabs: const [
            Tab(icon: Icon(Icons.lock_outline), text: 'Protect'),
            Tab(icon: Icon(Icons.lock_open_outlined), text: 'Unlock'),
            Tab(icon: Icon(Icons.branding_watermark_outlined), text: 'Watermark'),
          ],
        ),
      ),
      body: Column(
        children: [
          // File Picker Header
          Container(
            padding: const EdgeInsets.all(14),
            color: surfaceColor,
            child: Row(
              children: [
                const PdfFileIcon(size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      Text(
                        _file == null ? 'Tap change to select a PDF' : FileHelper.formatFileMeta(_file!),
                        style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _pickFile,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Change', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEncryptTab(isDark, surfaceColor, textColor),
                _buildDecryptTab(isDark, surfaceColor, textColor),
                _buildWatermarkTab(isDark, surfaceColor, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Encrypt Tab ────────────────────────────────────────────────────────────
  Widget _buildEncryptTab(bool isDark, Color surfaceColor, Color textColor) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Password Protection',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Encrypt this PDF with AES 256-bit encryption. Users will be required to enter the password to open the file.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePass,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.key, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off, color: AppColors.textFaint),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirmPasswordCtrl,
          obscureText: _obscurePass,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: const Icon(Icons.key_outlined, color: AppColors.primary),
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _isProcessing ? null : _encryptPdf,
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.lock),
          label: Text(_isProcessing ? 'Protecting...' : 'Protect PDF'),
        ),
      ],
    );
  }

  // ── Decrypt Tab ────────────────────────────────────────────────────────────
  Widget _buildDecryptTab(bool isDark, Color surfaceColor, Color textColor) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Remove Password Protection',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter the password to decrypt and create an unlocked copy of this PDF.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _decryptPasswordCtrl,
          obscureText: _obscurePass,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'PDF Password',
            prefixIcon: const Icon(Icons.lock_open, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off, color: AppColors.textFaint),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _isProcessing ? null : _decryptPdf,
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.lock_open),
          label: Text(_isProcessing ? 'Decrypting...' : 'Unlock PDF'),
        ),
      ],
    );
  }

  // ── Watermark Tab ──────────────────────────────────────────────────────────
  Widget _buildWatermarkTab(bool isDark, Color surfaceColor, Color textColor) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Add Watermark',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Stamp a custom text or logo image watermark across all pages of your PDF document.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Text Watermark
        TextField(
          controller: _watermarkTextCtrl,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Watermark Text',
            hintText: 'e.g. CONFIDENTIAL, DRAFT, DO NOT COPY',
            prefixIcon: const Icon(Icons.short_text, color: AppColors.primary),
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),

        // Quick presets
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['CONFIDENTIAL', 'DRAFT', 'APPROVED', 'DO NOT COPY', 'SAMPLE'].map((preset) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(preset),
                  backgroundColor: surfaceColor,
                  labelStyle: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                  onPressed: () => setState(() {
                    _watermarkTextCtrl.text = preset;
                    _watermarkImageFile = null;
                  }),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // Watermark Color Picker
        const Text('Watermark Color', style: TextStyle(color: AppColors.textFaint, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: _colorOptions.map((c) {
            final selected = _watermarkColor == c;
            return GestureDetector(
              onTap: () => setState(() {
                _watermarkColor = c;
                _watermarkImageFile = null;
              }),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: selected ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8)] : [],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Opacity Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Opacity', style: TextStyle(color: AppColors.textFaint, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${(_watermarkOpacity * 100).round()}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ],
        ),
        Slider(
          value: _watermarkOpacity,
          min: 0.1,
          max: 0.9,
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _watermarkOpacity = v),
        ),
        const SizedBox(height: 16),

        // Image Watermark Option
        OutlinedButton.icon(
          onPressed: _pickWatermarkImage,
          icon: Icon(Icons.image, color: isDark ? Colors.white : AppColors.primary),
          label: Text(
            _watermarkImageFile != null
                ? 'Logo Image: ${_watermarkImageFile!.path.split(Platform.pathSeparator).last}'
                : 'Use Image/Logo as Watermark',
            style: TextStyle(color: isDark ? Colors.white : AppColors.primary),
          ),
        ),
        const SizedBox(height: 24),

        FilledButton.icon(
          onPressed: _isProcessing ? null : _applyWatermark,
          icon: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.branding_watermark),
          label: Text(_isProcessing ? 'Applying Watermark...' : 'Apply Watermark'),
        ),
      ],
    );
  }
}
