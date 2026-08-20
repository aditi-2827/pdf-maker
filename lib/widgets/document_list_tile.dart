import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DocumentListTile extends StatelessWidget {
  final File file;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  const DocumentListTile({
    super.key,
    required this.file,
    required this.subtitle,
    this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final name = file.path.split(Platform.pathSeparator).last;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const PdfFileIcon(size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
                  ],
                ),
              ),
              if (onMore != null)
                IconButton(
                  icon: const Icon(Icons.more_vert, color: AppColors.textGray),
                  onPressed: onMore,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatFileMeta(File file) {
  final bytes = file.lengthSync();
  final size = bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  final modified = file.lastModifiedSync();
  final now = DateTime.now();
  final isToday = modified.year == now.year && modified.month == now.month && modified.day == now.day;
  final time = isToday
      ? 'Today, ${TimeOfDay.fromDateTime(modified).format24Hour()}'
      : '${modified.month}/${modified.day}/${modified.year}';
  return '$size • $time';
}

extension _TimeFormat on TimeOfDay {
  String format24Hour() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}