import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DocumentListTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final bool favorite;
  final VoidCallback? onFavoriteTap;

  const DocumentListTile({
    super.key,
    required this.name,
    required this.subtitle,
    this.onTap,
    this.onMore,
    this.favorite = false,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final divider = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E2D4A)
        : const Color(0xFFE5E7EB);
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: divider.withValues(alpha: 0.6)),
      ),
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
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (onFavoriteTap != null)
                IconButton(
                  icon: Icon(
                    favorite ? Icons.favorite : Icons.favorite_border,
                    color: favorite ? AppColors.danger : scheme.onSurfaceVariant,
                  ),
                  onPressed: onFavoriteTap,
                ),
              if (onMore != null)
                IconButton(
                  icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                  onPressed: onMore,
                ),
            ],
          ),
        ),
      ),
    );
  }
}