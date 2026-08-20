import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class FileHelper {
  /// Requests storage/media permission on Android.
  static Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return true;

      // Fallback for scoped storage devices (Android 13+)
      final photos = await Permission.photos.request();
      return photos.isGranted || status.isGranted;
    }
    return true;
  }

  /// Returns a folder inside app documents dir named "PdfMaker" to store outputs.
  static Future<Directory> getOutputDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory('${baseDir.path}/PdfMaker');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    return outputDir;
  }

  /// Saves bytes to a file with the given name inside the output dir.
  static Future<File> saveBytes(List<int> bytes, String fileName) async {
    final dir = await getOutputDir();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> openFile(String path) async {
    await OpenFile.open(path);
  }

  static Future<void> shareFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        await OpenFile.open(path);
        return;
      }

      String mimeType = 'application/pdf';
      final lower = path.toLowerCase();
      if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (lower.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (lower.endsWith('.txt')) {
        mimeType = 'text/plain';
      } else if (lower.endsWith('.docx')) {
        mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      }

      await Share.shareXFiles(
        [XFile(path, mimeType: mimeType)],
        subject: 'Shared from PDF Maker',
      );
    } catch (_) {
      await OpenFile.open(path);
    }
  }

  /// Lists all PDFs saved in the output folder, newest first.
  static Future<List<File>> listDocuments() async {
    final dir = await getOutputDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Formats file metadata string (e.g. Size: 1.2 MB).
  static String formatFileMeta(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) return 'Size: $bytes B';
      if (bytes < 1024 * 1024) return 'Size: ${(bytes / 1024).toStringAsFixed(1)} KB';
      return 'Size: ${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }
}