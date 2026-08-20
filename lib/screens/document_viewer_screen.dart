import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../theme/app_theme.dart';
import '../utils/file_helper.dart';
import 'share_export_screen.dart';
import 'reorder_pages_screen.dart';
import 'rotate_pages_screen.dart';
import 'metadata_editor_screen.dart';
import 'compress_screen.dart';
import 'split_screen.dart';
import 'pdf_security_screen.dart';
import 'pdf_annotation_widgets.dart';

class DocumentViewerScreen extends StatefulWidget {
  final File file;
  const DocumentViewerScreen({super.key, required this.file});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late File _currentFile;
  late pdfx.PdfControllerPinch _controller;
  int _viewKeyCounter = 0;

  AnnotationPlacementPayload? _activePlacement;
  Offset _overlayPosition = const Offset(60, 140);
  bool _isStamping = false;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file;
    _controller = pdfx.PdfControllerPinch(document: pdfx.PdfDocument.openFile(_currentFile.path));
  }

  void _reloadPdf(File newFile) {
    final oldController = _controller;
    setState(() {
      _currentFile = newFile;
      _viewKeyCounter++;
      _controller = pdfx.PdfControllerPinch(document: pdfx.PdfDocument.openFile(_currentFile.path));
      _activePlacement = null;
    });
    // Safely dispose old controller after frame completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController.dispose();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Open Annotation Modals & Receive Draggable Payload ──────────────────────
  Future<void> _startDraw() async {
    final payload = await showDialog<AnnotationPlacementPayload>(
      context: context,
      builder: (_) => DrawAnnotationDialog(pdfFile: _currentFile),
    );
    if (payload != null) {
      setState(() {
        _activePlacement = payload;
        _overlayPosition = const Offset(80, 160);
      });
    }
  }

  Future<void> _startSignature() async {
    final payload = await showDialog<AnnotationPlacementPayload>(
      context: context,
      builder: (_) => SignaturePadDialog(pdfFile: _currentFile),
    );
    if (payload != null) {
      setState(() {
        _activePlacement = payload;
        _overlayPosition = const Offset(80, 200);
      });
    }
  }

  Future<void> _startTextOverlay() async {
    final payload = await showDialog<AnnotationPlacementPayload>(
      context: context,
      builder: (_) => TextOverlayDialog(pdfFile: _currentFile),
    );
    if (payload != null) {
      setState(() {
        _activePlacement = payload;
        _overlayPosition = const Offset(60, 120);
      });
    }
  }

  // ── Stamp Draggable Overlay onto PDF ───────────────────────────────────────
  Future<void> _stampActivePlacement(Size viewerContainerSize) async {
    if (_activePlacement == null) return;
    setState(() => _isStamping = true);

    try {
      final doc = sf.PdfDocument(inputBytes: await _currentFile.readAsBytes());
      final pageIndex = (_activePlacement!.targetPage - 1).clamp(0, doc.pages.count - 1);
      final page = doc.pages[pageIndex];

      // Calculate relative scale from screen container to PDF page coordinates
      final pdfWidth = page.size.width;
      final pdfHeight = page.size.height;

      final scaleX = pdfWidth / viewerContainerSize.width;
      final scaleY = pdfHeight / viewerContainerSize.height;

      final pdfX = (_overlayPosition.dx * scaleX).clamp(0.0, pdfWidth - 40.0);
      final pdfY = (_overlayPosition.dy * scaleY).clamp(0.0, pdfHeight - 40.0);
      final stampW = _activePlacement!.width * scaleX;
      final stampH = _activePlacement!.height * scaleY;

      if (_activePlacement!.imageBytes != null) {
        // Stamp Image (Signature or Draw Annotation)
        final pdfBitmap = sf.PdfBitmap(_activePlacement!.imageBytes!);
        page.graphics.drawImage(
          pdfBitmap,
          Rect.fromLTWH(pdfX, pdfY, stampW, stampH),
        );
      } else if (_activePlacement!.text != null) {
        // Stamp Text
        final font = sf.PdfStandardFont(
          sf.PdfFontFamily.helvetica,
          _activePlacement!.fontSize ?? 18.0,
          style: sf.PdfFontStyle.bold,
        );
        final textColor = _activePlacement!.textColor ?? Colors.black;
        final pdfColor = sf.PdfColor(
          (textColor.r * 255.0).round().clamp(0, 255),
          (textColor.g * 255.0).round().clamp(0, 255),
          (textColor.b * 255.0).round().clamp(0, 255),
        );

        final textSize = font.measureString(_activePlacement!.text!);
        page.graphics.drawString(
          _activePlacement!.text!,
          font,
          brush: sf.PdfSolidBrush(pdfColor),
          bounds: Rect.fromLTWH(pdfX, pdfY, textSize.width, textSize.height),
        );
      }

      final outBytes = doc.saveSync();
      doc.dispose();

      final baseName = _currentFile.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');
      final outFile = await FileHelper.saveBytes(outBytes, '${baseName}_annotated.pdf');

      setState(() => _isStamping = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annotation stamped onto PDF successfully!'), backgroundColor: AppColors.primary),
      );

      _reloadPdf(outFile);
    } catch (e) {
      setState(() => _isStamping = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stamping annotation: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _currentFile.path.split(Platform.pathSeparator).last;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final surfaceBg = isDark ? AppColors.surface : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(name, overflow: TextOverflow.ellipsis),
        actions: [
          // ── ... Options Menu ───────────────────────────────────────────────
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: surfaceBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (value) async {
              switch (value) {
                case 'metadata':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MetadataEditorScreen(initialFile: _currentFile)),
                  );
                  break;
                case 'reorder':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReorderPagesScreen(initialFile: _currentFile)),
                  );
                  break;
                case 'rotate':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RotatePagesScreen(initialFile: _currentFile)),
                  );
                  break;
                case 'compress':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CompressScreen(initialFile: _currentFile)),
                  );
                  break;
                case 'split':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SplitScreen(initialFile: _currentFile)),
                  );
                  break;
                case 'security':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PdfSecurityScreen(initialFile: _currentFile)),
                  );
                  break;
                case 'export':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ShareExportScreen(file: _currentFile)),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'metadata',
                child: Row(
                  children: [
                    const Icon(Icons.edit_note, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Edit Metadata', style: TextStyle(color: textColor)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reorder',
                child: Row(
                  children: [
                    const Icon(Icons.reorder, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Reorder Pages', style: TextStyle(color: textColor)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rotate',
                child: Row(
                  children: [
                    const Icon(Icons.rotate_right, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Rotate Pages', style: TextStyle(color: textColor)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'compress',
                child: Row(
                  children: [
                    const Icon(Icons.compress, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Compress PDF', style: TextStyle(color: textColor)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'split',
                child: Row(
                  children: [
                    const Icon(Icons.call_split, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Split PDF', style: TextStyle(color: textColor)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'security',
                child: Row(
                  children: [
                    const Icon(Icons.security, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Security & Watermark', style: TextStyle(color: textColor)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    const Icon(Icons.ios_share, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Export & Share', style: TextStyle(color: textColor)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner instruction when placement mode active
          if (_activePlacement != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primary.withValues(alpha: 0.2),
              child: Row(
                children: [
                  const Icon(Icons.open_with, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Drag overlay box to position it anywhere on page',
                      style: TextStyle(color: textColor, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _activePlacement = null),
                    icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
                    label: const Text('Cancel', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Base PDF View Container
                    Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: pdfx.PdfViewPinch(
                        key: ValueKey('pdf_view_$_viewKeyCounter'),
                        controller: _controller,
                      ),
                    ),

                    // Draggable Overlay Item
                    if (_activePlacement != null)
                      Positioned(
                        left: _overlayPosition.dx,
                        top: _overlayPosition.dy,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              final newX = (_overlayPosition.dx + details.delta.dx).clamp(
                                12.0,
                                constraints.maxWidth - _activePlacement!.width - 12.0,
                              );
                              final newY = (_overlayPosition.dy + details.delta.dy).clamp(
                                12.0,
                                constraints.maxHeight - _activePlacement!.height - 12.0,
                              );
                              _overlayPosition = Offset(newX, newY);
                            });
                          },
                          child: Container(
                            width: _activePlacement!.width,
                            height: _activePlacement!.height,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: _activePlacement!.imageBytes != null
                                      ? Image.memory(_activePlacement!.imageBytes!, fit: BoxFit.contain)
                                      : Text(
                                          _activePlacement!.text ?? '',
                                          style: TextStyle(
                                            color: _activePlacement!.textColor ?? Colors.black,
                                            fontSize: _activePlacement!.fontSize ?? 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                const Align(
                                  alignment: Alignment.topRight,
                                  child: Icon(Icons.drag_handle, color: AppColors.primary, size: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // Bottom Bar or Apply Overlay Banner
          if (_activePlacement != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: surfaceBg,
              child: FilledButton.icon(
                onPressed: _isStamping ? null : () => _stampActivePlacement(MediaQuery.of(context).size),
                icon: _isStamping
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isStamping ? 'Stamping...' : 'Stamp Annotation onto PDF'),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: surfaceBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BarAction(
                    icon: Icons.draw_outlined,
                    label: 'Draw',
                    textColor: textColor,
                    onTap: _startDraw,
                  ),
                  _BarAction(
                    icon: Icons.gesture,
                    label: 'Sign',
                    textColor: textColor,
                    onTap: _startSignature,
                  ),
                  _BarAction(
                    icon: Icons.title,
                    label: 'Text',
                    textColor: textColor,
                    onTap: _startTextOverlay,
                  ),
                  _BarAction(
                    icon: Icons.security,
                    label: 'Security',
                    textColor: textColor,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PdfSecurityScreen(initialFile: _currentFile)),
                      );
                    },
                  ),
                  _BarAction(
                    icon: Icons.ios_share,
                    label: 'Share',
                    textColor: textColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ShareExportScreen(file: _currentFile)),
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

class _BarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final VoidCallback onTap;
  const _BarAction({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: textColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}