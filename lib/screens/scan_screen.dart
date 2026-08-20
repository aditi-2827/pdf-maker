import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'scan_review_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    // Launch camera scanner directly on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchScanner();
    });
  }

  /// Launch the native document scanner with edge detection
  Future<void> _launchScanner() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final pictures = await CunningDocumentScanner.getPictures(
        noOfPages: 20,
        isGalleryImportAllowed: false,
      );
      if (!mounted) return;
      if (pictures != null && pictures.isNotEmpty) {
        final files = pictures.map((p) => File(p)).toList();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ScanReviewScreen(pages: files)),
        );
      } else {
        // User canceled scanning
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanner error: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Import from gallery
  Future<void> _pickFromGallery() async {
    setState(() => _scanning = true);
    try {
      final results = await _picker.pickMultiImage(imageQuality: 90);
      if (!mounted) return;
      if (results.isNotEmpty) {
        final files = results.map((x) => File(x.path)).toList();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ScanReviewScreen(pages: files)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gallery error: $e')),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Document'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 20),
            Text(
              'Opening Camera Scanner...',
              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _launchScanner,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Re-open Camera Scanner'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library),
              label: const Text('Import Scans from Gallery'),
            ),
          ],
        ),
      ),
    );
  }
}