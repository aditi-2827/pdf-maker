import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/file_helper.dart';
import '../widgets/document_list_tile.dart';
import 'scan_screen.dart';
import 'document_viewer_screen.dart';

enum _Tab { all, recent, favorites, shared }

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<File> _all = [];
  bool _loading = true;
  _Tab _tab = _Tab.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final docs = await FileHelper.listDocuments();
    setState(() {
      _all = docs;
      _loading = false;
    });
  }

  List<File> get _filtered {
    Iterable<File> docs = _all;
    if (_tab == _Tab.recent) docs = docs.take(10);
    if (_query.isNotEmpty) {
      docs = docs.where((f) => f.path.toLowerCase().contains(_query.toLowerCase()));
    }
    return docs.toList();
  }

  void _showFileOptions(File file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new, color: Colors.white),
              title: const Text('Open', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentViewerScreen(file: file)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Share', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                FileHelper.shareFile(file.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Delete', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(context);
                await file.delete();
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(String label, _Tab tab) {
    final selected = _tab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _tab = tab),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textFaint, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final showPlaceholder = _tab == _Tab.favorites || _tab == _Tab.shared;

    return Scaffold(
      appBar: AppBar(title: const Text('My Documents')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
          _load();
        },
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'Search all documents...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _tabChip('All', _Tab.all),
                _tabChip('Recent', _Tab.recent),
                _tabChip('Favorites', _Tab.favorites),
                _tabChip('Shared', _Tab.shared),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
            else if (showPlaceholder)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: Text('Not available yet', style: TextStyle(color: AppColors.textFaint))),
              )
            else if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('No documents found', style: TextStyle(color: AppColors.textFaint))),
                )
              else
                Column(
                  children: items
                      .map(
                        (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DocumentListTile(
                        file: f,
                        subtitle: formatFileMeta(f),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentViewerScreen(file: f))),
                        onMore: () => _showFileOptions(f),
                      ),
                    ),
                  )
                      .toList(),
                ),
          ],
        ),
      ),
    );
  }
}