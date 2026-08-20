import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/file_helper.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/document_list_tile.dart';
import '../widgets/section_header.dart';
import 'scan_screen.dart';
import 'image_to_pdf_screen.dart';
import 'merge_documents_screen.dart';
import 'documents_screen.dart';
import 'document_viewer_screen.dart';
import 'compress_screen.dart';
import 'split_screen.dart';
import 'pdf_security_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final docs = await FileHelper.listDocuments();
    setState(() {
      _recent = docs.take(4).toList();
      _loading = false;
    });
  }

  Future<void> _refreshOnReturn() async {
    await _loadRecent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRecent,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header
              Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary,
                    child: Text('JS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back,', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                        Text('PDF Maker', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.notifications_none, color: Colors.white, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Theme toggle row ──────────────────────────────────────────
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (ctx, mode, _) {
                  final isDark = mode == ThemeMode.dark;
                  return Row(
                    children: [
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          themeNotifier.value =
                              isDark ? ThemeMode.light : ThemeMode.dark;
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          width: 72,
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surface
                                : const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.primary.withValues(alpha: 0.4)
                                  : AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedAlign(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                alignment: isDark
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      )
                                    ],
                                  ),
                                  child: Icon(
                                    isDark ? Icons.dark_mode : Icons.light_mode,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'QUICK ACTIONS'),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.6,
                children: [
                  QuickActionCard(
                    label: 'Scan Document',
                    icon: Icons.camera_alt_outlined,
                    selected: true,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
                      _refreshOnReturn();
                    },
                  ),
                  QuickActionCard(
                    label: 'Create PDF',
                    icon: Icons.add_box_outlined,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ImageToPdfScreen()));
                      _refreshOnReturn();
                    },
                  ),
                  QuickActionCard(
                    label: 'Merge PDFs',
                    icon: Icons.call_merge,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const MergeDocumentsScreen()));
                      _refreshOnReturn();
                    },
                  ),
                  QuickActionCard(
                    label: 'Compress PDF',
                    icon: Icons.compress,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const CompressScreen()));
                      _refreshOnReturn();
                    },
                  ),
                  QuickActionCard(
                    label: 'Split PDF',
                    icon: Icons.call_split,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const SplitScreen()));
                      _refreshOnReturn();
                    },
                  ),
                  QuickActionCard(
                    label: 'Security & Watermark',
                    icon: Icons.security,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfSecurityScreen()));
                      _refreshOnReturn();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 28),

              SectionHeader(
                title: 'RECENT DOCUMENTS',
                trailing: 'View All',
                onTrailingTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen()));
                  _refreshOnReturn();
                },
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text('No documents yet — try Scan or Create PDF', style: TextStyle(color: AppColors.textFaint)),
                  ),
                )
              else
                Column(
                  children: _recent
                      .map(
                        (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DocumentListTile(
                        file: f,
                        subtitle: formatFileMeta(f),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DocumentViewerScreen(file: f)),
                          );
                          _refreshOnReturn();
                        },
                      ),
                    ),
                  )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}