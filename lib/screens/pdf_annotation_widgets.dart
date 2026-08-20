import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../theme/app_theme.dart';

class AnnotationPlacementPayload {
  final Uint8List? imageBytes;
  final String? text;
  final Color? textColor;
  final double? fontSize;
  final double width;
  final double height;
  final int targetPage;

  AnnotationPlacementPayload({
    this.imageBytes,
    this.text,
    this.textColor,
    this.fontSize,
    required this.width,
    required this.height,
    required this.targetPage,
  });
}

// ─── Freehand Stroke model ───────────────────────────────────────────────────
class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  _Stroke({required this.points, required this.color, required this.width});
}

// ─── 1. DIGITAL SIGNATURE DIALOG ─────────────────────────────────────────────
class SignaturePadDialog extends StatefulWidget {
  final File pdfFile;

  const SignaturePadDialog({
    super.key,
    required this.pdfFile,
  });

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final List<_Stroke> _strokes = [];
  _Stroke? _currentStroke;
  Color _penColor = Colors.black;
  final double _strokeWidth = 3.0;
  bool _isSaving = false;
  int _targetPage = 1;
  int _totalPages = 1;

  final List<Color> _penColors = [
    Colors.black,
    const Color(0xFF003366), // Deep navy blue
    Colors.red,
    Colors.purple,
  ];

  @override
  void initState() {
    super.initState();
    _loadPageCount();
  }

  void _loadPageCount() {
    try {
      final doc = PdfDocument(inputBytes: widget.pdfFile.readAsBytesSync());
      setState(() {
        _totalPages = doc.pages.count;
      });
      doc.dispose();
    } catch (_) {}
  }

  Future<ui.Image> _renderCanvasToImage(Size canvasSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height));

    for (final stroke in _strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }

    final picture = recorder.endRecording();
    return await picture.toImage(canvasSize.width.toInt(), canvasSize.height.toInt());
  }

  Future<void> _prepareSignature() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw your signature first.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final img = await _renderCanvasToImage(const Size(400, 200));
      final pngData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (pngData == null) throw Exception('Could not render signature PNG');

      final pngBytes = pngData.buffer.asUint8List();

      setState(() => _isSaving = false);
      if (!mounted) return;

      Navigator.pop(
        context,
        AnnotationPlacementPayload(
          imageBytes: pngBytes,
          width: 180,
          height: 90,
          targetPage: _targetPage,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.gesture, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Draw Signature',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textFaint),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Pen Color Selection
            Row(
              children: [
                const Text('Ink Color:', style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
                const SizedBox(width: 10),
                ..._penColors.map((c) {
                  final selected = _penColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _penColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? AppColors.primary : Colors.white24,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _strokes.clear()),
                  icon: const Icon(Icons.delete_sweep, size: 18, color: AppColors.danger),
                  label: const Text('Clear', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Signature Drawing Area
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _currentStroke = _Stroke(
                      points: [details.localPosition],
                      color: _penColor,
                      width: _strokeWidth,
                    );
                    _strokes.add(_currentStroke!);
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentStroke?.points.add(details.localPosition);
                  });
                },
                onPanEnd: (_) => _currentStroke = null,
                child: CustomPaint(
                  painter: _SignaturePainter(strokes: _strokes),
                  size: Size.infinite,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Target Page Picker
            if (_totalPages > 1)
              Row(
                children: [
                  const Text('Stamp on Page:', style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _targetPage,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white),
                    items: List.generate(_totalPages, (i) => i + 1).map((p) {
                      return DropdownMenuItem<int>(
                        value: p,
                        child: Text('Page $p of $_totalPages'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _targetPage = v);
                    },
                  ),
                ],
              ),
            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: _isSaving ? null : _prepareSignature,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.open_with),
              label: Text(_isSaving ? 'Preparing...' : 'Place Signature on Page'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<_Stroke> strokes;
  _SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── 2. FREEHAND DRAWING / ANNOTATION DIALOG ─────────────────────────────────
class DrawAnnotationDialog extends StatefulWidget {
  final File pdfFile;

  const DrawAnnotationDialog({
    super.key,
    required this.pdfFile,
  });

  @override
  State<DrawAnnotationDialog> createState() => _DrawAnnotationDialogState();
}

class _DrawAnnotationDialogState extends State<DrawAnnotationDialog> {
  final List<_Stroke> _strokes = [];
  _Stroke? _currentStroke;
  Color _penColor = Colors.red;
  double _strokeWidth = 4.0;
  bool _isSaving = false;
  int _targetPage = 1;
  int _totalPages = 1;

  final List<Color> _penColors = [
    Colors.red,
    Colors.blue,
    Colors.yellow,
    Colors.green,
    Colors.orange,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _loadPageCount();
  }

  void _loadPageCount() {
    try {
      final doc = PdfDocument(inputBytes: widget.pdfFile.readAsBytesSync());
      setState(() => _totalPages = doc.pages.count);
      doc.dispose();
    } catch (_) {}
  }

  Future<void> _prepareDrawing() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw an annotation first.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 500, 500));

      for (final stroke in _strokes) {
        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        for (int i = 0; i < stroke.points.length - 1; i++) {
          canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
        }
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(500, 500);
      final pngData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (pngData == null) throw Exception('Could not render drawing PNG');

      final pngBytes = pngData.buffer.asUint8List();

      setState(() => _isSaving = false);
      if (!mounted) return;

      Navigator.pop(
        context,
        AnnotationPlacementPayload(
          imageBytes: pngBytes,
          width: 240,
          height: 240,
          targetPage: _targetPage,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.draw, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Draw Annotation',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textFaint),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            // Pen Color options
            Row(
              children: [
                ..._penColors.map((c) {
                  final selected = _penColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _penColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white24,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.white),
                  onPressed: () {
                    if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => setState(() => _strokes.clear()),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Canvas area
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              clipBehavior: Clip.antiAlias,
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _currentStroke = _Stroke(
                      points: [details.localPosition],
                      color: _penColor,
                      width: _strokeWidth,
                    );
                    _strokes.add(_currentStroke!);
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentStroke?.points.add(details.localPosition);
                  });
                },
                onPanEnd: (_) => _currentStroke = null,
                child: CustomPaint(
                  painter: _SignaturePainter(strokes: _strokes),
                  size: Size.infinite,
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                const Text('Stroke Width:', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _strokeWidth,
                    min: 1.0,
                    max: 12.0,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _strokeWidth = v),
                  ),
                ),
              ],
            ),

            if (_totalPages > 1)
              Row(
                children: [
                  const Text('Page:', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _targetPage,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white),
                    items: List.generate(_totalPages, (i) => i + 1).map((p) {
                      return DropdownMenuItem<int>(value: p, child: Text('Page $p'));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _targetPage = v);
                    },
                  ),
                ],
              ),
            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed: _isSaving ? null : _prepareDrawing,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.open_with),
              label: Text(_isSaving ? 'Preparing...' : 'Place Drawing on Page'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 3. TEXT OVERLAY DIALOG ──────────────────────────────────────────────────
class TextOverlayDialog extends StatefulWidget {
  final File pdfFile;

  const TextOverlayDialog({
    super.key,
    required this.pdfFile,
  });

  @override
  State<TextOverlayDialog> createState() => _TextOverlayDialogState();
}

class _TextOverlayDialogState extends State<TextOverlayDialog> {
  final _textCtrl = TextEditingController();
  double _fontSize = 18.0;
  Color _textColor = Colors.black;
  int _targetPage = 1;
  int _totalPages = 1;

  final List<Color> _colors = [
    Colors.black,
    Colors.red,
    const Color(0xFF003366),
    Colors.green,
    Colors.orange,
  ];

  @override
  void initState() {
    super.initState();
    _loadPageCount();
  }

  void _loadPageCount() {
    try {
      final doc = PdfDocument(inputBytes: widget.pdfFile.readAsBytesSync());
      setState(() => _totalPages = doc.pages.count);
      doc.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _prepareTextOverlay() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to add onto PDF.')),
      );
      return;
    }

    Navigator.pop(
      context,
      AnnotationPlacementPayload(
        text: text,
        textColor: _textColor,
        fontSize: _fontSize,
        width: (text.length * _fontSize * 0.75).clamp(120.0, 320.0),
        height: _fontSize * 2.2,
        targetPage: _targetPage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.title, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Add Text Overlay',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textFaint),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _textCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Text Content',
                hintText: 'e.g. APPROVED BY JOHN, DRAFT',
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // Color picker
            Row(
              children: [
                const Text('Color:', style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
                const SizedBox(width: 10),
                ..._colors.map((c) {
                  final selected = _textColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _textColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? AppColors.primary : Colors.white24,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),

            // Font size slider
            Row(
              children: [
                Text('Size: ${_fontSize.round()}pt', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 10.0,
                    max: 48.0,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),
              ],
            ),

            if (_totalPages > 1)
              Row(
                children: [
                  const Text('Target Page:', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _targetPage,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: List.generate(_totalPages, (i) => i + 1)
                        .map((p) => DropdownMenuItem(value: p, child: Text('Page $p')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _targetPage = v);
                    },
                  ),
                ],
              ),
            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _prepareTextOverlay,
              icon: const Icon(Icons.open_with),
              label: const Text('Place Text on Page'),
            ),
          ],
        ),
      ),
    );
  }
}
