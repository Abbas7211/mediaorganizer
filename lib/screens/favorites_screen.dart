import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '../core/constants.dart';
import '../hive/models/library_item.dart';
import '../managers/download_manager.dart';
import '../sheets/media_actions_sheet.dart';
import '../widgets/media_list_card.dart';

enum FavSortBy { name, date, size }

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  final Set<String> _selectedIds = <String>{};
  bool get _selectMode => _selectedIds.isNotEmpty;

  FavSortBy _sortBy = FavSortBy.date;
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------- helpers ----------
  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  String _timeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return 'Added ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'Added ${diff.inHours} hours ago';
    return 'Added ${diff.inDays} days ago';
  }

  int _safeSizeBytes(LibraryItem it) {
    try {
      final f = File(it.filePath);
      if (!f.existsSync()) return 0;
      return f.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  // ---------- selection ----------
  int get _selectedCount => _selectedIds.length;

  List<LibraryItem> get _selectedItems {
    final set = _selectedIds;
    return downloadManager.favoriteItems.where((e) => set.contains(e.id)).toList();
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  void _toggleSelected(LibraryItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  void _selectAllVisible(List<LibraryItem> visible) {
    setState(() {
      for (final it in visible) {
        _selectedIds.add(it.id);
      }
    });
  }

  // ---------- filtering/sorting ----------
  List<LibraryItem> _filterSort(List<LibraryItem> all) {
    final filtered = all.where((it) {
      if (_query.isEmpty) return true;
      return it.displayTitle.toLowerCase().contains(_query);
    }).toList();

    int cmp(LibraryItem a, LibraryItem b) {
      switch (_sortBy) {
        case FavSortBy.name:
          return a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase());
        case FavSortBy.date:
          return a.createdAt.compareTo(b.createdAt);
        case FavSortBy.size:
          return _safeSizeBytes(a).compareTo(_safeSizeBytes(b));
      }
    }

    filtered.sort((a, b) => _ascending ? cmp(a, b) : cmp(b, a));
    return filtered;
  }

  // ---------- actions ----------
  Future<void> _openWith(LibraryItem item) async {
    final file = File(item.filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found on device.')),
      );
      return;
    }

    final result = await OpenFilex.open(item.filePath);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open file: ${result.message}')),
      );
    }
  }

  Future<void> _showDetails(LibraryItem item) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final thumb = item.thumbnailPath;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 180,
                      child: (thumb != null && thumb.isNotEmpty && File(thumb).existsSync())
                          ? Image.file(File(thumb), fit: BoxFit.cover)
                          : Container(
                        color: Colors.black26,
                        child: const Icon(Icons.play_circle_outline, size: 46),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Name: ${item.title}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Date & time: ${_fmtDate(item.createdAt)}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text('Size: ${_fmtBytes(item.sizeBytes)}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text('Source URL: ${item.url ?? "—"}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy URL'),
                  onTap: () {
                    final u = item.url ?? '';
                    if (u.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: u));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL copied')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _renameSelected() async {
    if (_selectedItems.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select 1 item to rename.')),
      );
      return;
    }

    final item = _selectedItems.first;
    final c = TextEditingController(text: item.title);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text('Rename'),
        content: TextField(controller: c),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      downloadManager.renameItem(item, newName);
      _clearSelection();
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedItems.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text('Delete'),
        content: Text('Delete ${_selectedItems.length} item(s)?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (ok == true) {
      for (final item in _selectedItems) {
        downloadManager.removeMedia(item);
        try {
          final f = File(item.filePath);
          if (await f.exists()) await f.delete();
          final t = item.thumbnailPath;
          if (t != null && t.isNotEmpty) {
            final tf = File(t);
            if (await tf.exists()) await tf.delete();
          }
        } catch (_) {}
      }
      _clearSelection();
    }
  }

  Future<void> _moveSelected() async {
    if (_selectedItems.isEmpty) return;

    const cancel = '__CANCEL__';

    final chosen = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Root'),
              onTap: () => Navigator.pop(ctx, null), // Root is valid
            ),
            const Divider(height: 1),
            ...downloadManager.mediaFolders.map(
                  (f) => ListTile(
                leading: const Icon(Icons.folder),
                title: Text(f.name),
                onTap: () => Navigator.pop(ctx, f.id),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (chosen == null && Navigator.of(context).canPop() == false) {} // ignore
    if (chosen == null) {
      final confirmRoot = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          backgroundColor: kCardColor,
          title: const Text('Move to Root?'),
          content: const Text(
            'Move selected item(s) to Root?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Move')),
          ],
        ),
      );

      if (confirmRoot != true) return;
    }

    await downloadManager.moveLibraryItemsToFolder(_selectedItems, chosen);
    _clearSelection();
  }

  // ---------- UI ----------
  Widget _sortBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<FavSortBy>(
                value: _sortBy,
                dropdownColor: kCardColor,
                iconEnabledColor: Colors.white70,
                items: const [
                  DropdownMenuItem(value: FavSortBy.name, child: Text('Name')),
                  DropdownMenuItem(value: FavSortBy.date, child: Text('Date')),
                  DropdownMenuItem(value: FavSortBy.size, child: Text('Size')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _sortBy = v);
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            tooltip: _ascending ? 'Ascending' : 'Descending',
            icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => setState(() => _ascending = !_ascending),
          ),
        ),
      ],
    );
  }

  Widget _bottomAction(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: Colors.white70),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }

  void _handleBack() {
    if (_selectMode) {
      _clearSelection();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_selectMode,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_selectMode ? 'Select items ($_selectedCount)' : 'Favorites'),
          backgroundColor: kBgColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          actions: [
            if (_selectMode) ...[
              TextButton(
                onPressed: () => _selectAllVisible(_filterSort(downloadManager.favoriteItems)),
                child: const Text('All', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: _clearSelection,
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ],
        ),
        backgroundColor: kBgColor,
        body: AnimatedBuilder(
          animation: downloadManager,
          builder: (context, _) {
            final items = _filterSort(downloadManager.favoriteItems);

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search favorites',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.mic_none),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sort bar
                  _sortBar(),
                  const SizedBox(height: 14),

                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                      child: Text(
                        'No favorites yet.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    )
                        : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = _selectedIds.contains(item.id);

                        return GestureDetector(
                          onLongPress: () => setState(() => _selectedIds.add(item.id)),
                          onTap: () {
                            if (_selectMode) {
                              _toggleSelected(item);
                            } else {
                              _openWith(item);
                            }
                          },
                          child: MediaListCard(
                            item: item,
                            addedText: _timeAgo(item.createdAt),
                            selected: selected,
                            sizeText: _fmtBytes(item.sizeBytes),
                            onMore: () => showMediaActionsSheet(context, item),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom selection actions
                  if (_selectMode && _selectedCount > 0)
                    SafeArea(
                      child: Container(
                        color: const Color(0xFF101117),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _bottomAction('Move', Icons.drive_file_move, _moveSelected),
                            _bottomAction('Details', Icons.info_outline, () {
                              if (_selectedItems.length == 1) {
                                _showDetails(_selectedItems.first);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Select 1 item to view details.')),
                                );
                              }
                            }),
                            _bottomAction('Rename', Icons.edit, _renameSelected),
                            _bottomAction('Delete', Icons.delete_outline, _deleteSelected),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
