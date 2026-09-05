import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/file_helper.dart';
import '../services/firestore_service.dart';
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
    FirestoreService.instance.favoritesNames.addListener(_onCloudChanged);
    FirestoreService.instance.recentlySharedNames.addListener(_onCloudChanged);
  }

  @override
  void dispose() {
    FirestoreService.instance.favoritesNames.removeListener(_onCloudChanged);
    FirestoreService.instance.recentlySharedNames.removeListener(_onCloudChanged);
    super.dispose();
  }

  void _onCloudChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final docs = await FileHelper.listDocuments();
    await FirestoreService.instance.refresh();
    if (!mounted) return;
    setState(() {
      _all = docs;
      _loading = false;
    });
  }

  String _nameOf(File f) => f.path.split(Platform.pathSeparator).last;

  List<File> get _filtered {
    Iterable<File> docs = _all;
    if (_tab == _Tab.recent) {
      docs = docs.take(10);
    } else if (_tab == _Tab.favorites) {
      final favs = FirestoreService.instance.favoritesNames.value;
      docs = docs.where((f) => favs.contains(_nameOf(f)));
    } else if (_tab == _Tab.shared) {
      final shared = FirestoreService.instance.recentlySharedNames.value;
      final filesByName = {for (final f in _all) _nameOf(f): f};
      docs = shared.map((n) => filesByName[n]).whereType<File>().toList();
    }
    if (_query.isNotEmpty) {
      docs = docs.where((f) => _nameOf(f).toLowerCase().contains(_query.toLowerCase()));
    }
    return docs.toList();
  }

  Future<void> _toggleFavorite(File file) async {
    final name = _nameOf(file);
    final isFav = FirestoreService.instance.favoritesNames.value.contains(name);
    await FirestoreService.instance.toggleFavorite(name, add: !isFav);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isFav ? 'Removed from favorites' : 'Added to favorites')),
    );
  }

  void _showFileOptions(File file) {
    final scheme = Theme.of(context).colorScheme;
    final name = _nameOf(file);
    final isFav = FirestoreService.instance.favoritesNames.value.contains(name);

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.open_in_new, color: scheme.onSurface),
              title: Text('Open', style: TextStyle(color: scheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentViewerScreen(file: file)));
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: scheme.onSurface),
              title: Text('Share', style: TextStyle(color: scheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                FileHelper.shareFile(file.path);
                FirestoreService.instance.recordShare(name);
              },
            ),
            ListTile(
              leading: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? AppColors.danger : scheme.onSurface),
              title: Text(isFav ? 'Remove from Favorites' : 'Add to Favorites', style: TextStyle(color: scheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _toggleFavorite(file);
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
    final scheme = Theme.of(context).colorScheme;
    final selected = _tab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _tab = tab),
        selectedColor: AppColors.primary,
        backgroundColor: scheme.surface,
        labelStyle: TextStyle(
          color: selected ? Colors.white : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
      ),
    );
  }

  String _emptyMessage() {
    switch (_tab) {
      case _Tab.favorites:
        if (!FirestoreService.isConfigured) {
          return 'Cloud not connected — set up Firebase to sync favorites';
        }
        return 'No favorites yet — tap the ♥ on any document';
      case _Tab.shared:
        return 'No sharing history yet — share a document to see it here';
      default:
        return _query.isNotEmpty ? 'No documents match your search' : 'No documents found';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _filtered;

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
              style: TextStyle(color: scheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search all documents...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: scheme.surface,
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
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    _emptyMessage(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              Column(
                children: items
                    .map(
                      (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DocumentListTile(
                      name: _nameOf(f),
                      subtitle: FileHelper.formatFileMeta(f),
                      favorite: FirestoreService.instance.favoritesNames.value.contains(_nameOf(f)),
                      onFavoriteTap: () => _toggleFavorite(f),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DocumentViewerScreen(file: f)),
                      ),
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