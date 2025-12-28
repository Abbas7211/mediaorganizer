import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '../screens/browser_screen.dart';
import '../core/constants.dart';
import '../hive/models/library_item.dart';
import '../hive/models/media_folder.dart';
import '../managers/download_manager.dart';
import '../sheets/media_actions_sheet.dart';
import '../widgets/media_list_card.dart';

enum MediaSortBy { name, date, size }

class MediaListScreen extends StatefulWidget {
  const MediaListScreen({super.key});

  @override
  State<MediaListScreen> createState() => _MediaListScreenState();
}

class _MediaListScreenState extends State<MediaListScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String? _currentFolderId; // null = Root

  final Set<String> _selectedIds = <String>{};
  bool get _selectMode => _selectedIds.isNotEmpty;

  MediaSortBy _sortBy = MediaSortBy.date;
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

  // ---------- formatting ----------
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

  String _folderNameById(String? id) {
    if (id == null) return 'Root';
    final hit = downloadManager.mediaFolders.where((f) => f.id == id).toList();
    return hit.isEmpty ? 'Folder' : hit.first.name;
  }

  // ---------- selection ----------
  int get _selectedCount => _selectedIds.length;

  List<LibraryItem> get _selectedItems {
    final set = _selectedIds;
    return downloadManager.libraryItems.where((e) => set.contains(e.id)).toList();
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

  // ---------- back handling (fixes “exit app” issue) ----------
  void _handleBack() {
    if (_selectMode) {
      _clearSelection();
      return;
    }
    if (_currentFolderId != null) {
      setState(() => _currentFolderId = null);
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // ---------- visible data ----------
  List<MediaFolder> _visibleFolders() {
    if (_currentFolderId != null) return [];
    final folders = downloadManager.mediaFolders;
    if (_query.isEmpty) return folders;
    return folders.where((f) => f.name.toLowerCase().contains(_query)).toList();
  }

  List<LibraryItem> _visibleItems() {
    final all = downloadManager.libraryItems;

    var items = all.where((it) {
      final sameFolder = (_currentFolderId == null)
          ? (it.folderId == null)
          : (it.folderId == _currentFolderId);

      if (!sameFolder) return false;
      if (_query.isEmpty) return true;
      return it.displayTitle.toLowerCase().contains(_query);
    }).toList();

    int cmp(LibraryItem a, LibraryItem b) {
      switch (_sortBy) {
        case MediaSortBy.name:
          return a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase());
        case MediaSortBy.date:
          return a.createdAt.compareTo(b.createdAt);
        case MediaSortBy.size:
          return a.sizeBytes.compareTo(b.sizeBytes);
      }
    }

    items.sort((a, b) => _ascending ? cmp(a, b) : cmp(b, a));
    return items;
  }

  // ---------- actions ----------
  Future<void> _openWith(LibraryItem item) async {
    final file = File(item.filePath);
    if (!await file.exists()) {
      if (!mounted) return;

      final u = (item.url ?? '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("This item was retrieved from Firebase (metadata only). Can't re-download yet. Open source URL instead."),
          action: (u.isEmpty)
              ? null
              : SnackBarAction(
            label: 'Open',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BrowserScreen(initialUrl: u),
                ),
              );
            },
          ),
        ),
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



  Future<void> _createFolderDialog() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text('Create folder'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Create')),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await downloadManager.createMediaFolder(name);
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

// ✅ dismissed => do nothing
    if (!mounted) return;
    if (chosen == null && Navigator.of(context).canPop() == false) {} // ignore
// better:
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

// now chosen is either folderId OR null (confirmed root)
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
              child: DropdownButton<MediaSortBy>(
                value: _sortBy,
                dropdownColor: kCardColor,
                iconEnabledColor: Colors.white70,
                items: const [
                  DropdownMenuItem(value: MediaSortBy.name, child: Text('Name')),
                  DropdownMenuItem(value: MediaSortBy.date, child: Text('Date')),
                  DropdownMenuItem(value: MediaSortBy.size, child: Text('Size')),
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

  Future<void> _folderLongPressMenu(MediaFolder f) async {
    final count = downloadManager.mediaFolderCount(f.id);

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Details'),
              onTap: () => Navigator.pop(ctx, 'details'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'details') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder: ${f.name} • $count items')),
      );
      return;
    }

    if (choice == 'rename') {
      if (!mounted) return;
      final c = TextEditingController(text: f.name);
      final newName = await showDialog<String>(
        context: context,
        builder: (dCtx) => AlertDialog(
          backgroundColor: kCardColor,
          title: const Text('Rename folder'),
          content: TextField(controller: c),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(dCtx, c.text.trim()), child: const Text('Save')),
          ],
        ),
      );
      if (newName != null && newName.isNotEmpty) {
        await downloadManager.renameMediaFolder(f, newName);
      }
      return;
    }

    if (choice == 'delete') {
      if (!mounted) return;
      final ok = await showDialog<bool> (
        context: context,
        builder: (dCtx) => AlertDialog(
          backgroundColor: kCardColor,
          title: const Text('Delete folder'),
          content: const Text(
            'Folder will be deleted. Items will move to Root.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (ok == true) {
        await downloadManager.deleteMediaFolder(f);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_selectMode && _currentFolderId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(_selectMode ? 'Select items ($_selectedCount)' : 'Media List'),
          backgroundColor: kBgColor,
          elevation: 0,
          actions: [
            if (!_selectMode) ...[
              IconButton(
                tooltip: 'Create folder',
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: _createFolderDialog,
              ),
            ] else ...[
              TextButton(
                onPressed: () => _selectAllVisible(_visibleItems()),
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
            final folders = _visibleFolders();
            final items = _visibleItems();
            final totalBytes = items.fold<int>(0, (sum, it) => sum + it.sizeBytes);

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
                              hintText: 'Search media',
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

                  const SizedBox(height: 10),

                  // Breadcrumb (under search)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () {
                        if (_currentFolderId != null) {
                          setState(() => _currentFolderId = null);
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_open, size: 18, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            _currentFolderId == null ? 'Root' : 'Root  ›  ${_folderNameById(_currentFolderId)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Count card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${items.length} videos (${_fmtBytes(totalBytes)})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Sort bar (matches Favorites style)
                  _sortBar(),

                  const SizedBox(height: 14),

                  Expanded(
                    child: ListView(
                      children: [
                        // Folders (Root only)
                        if (_currentFolderId == null && folders.isNotEmpty) ...[
                          ...folders.map((f) {
                            final count = downloadManager.mediaFolderCount(f.id);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: kCardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                onTap: () => setState(() => _currentFolderId = f.id),
                                onLongPress: () => _folderLongPressMenu(f),
                                leading: const Icon(Icons.folder, color: Colors.white70),
                                title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: Text(
                                  '$count item${count == 1 ? '' : 's'}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],

                        // Videos
                        if (items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(
                              child: Text('No videos here.', style: TextStyle(color: Colors.white60)),
                            ),
                          )
                        else
                          ...items.map((item) {
                            final selected = _selectedIds.contains(item.id);

                            return GestureDetector(
                              onLongPress: () {
                                setState(() => _selectedIds.add(item.id));
                              },
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
                          }),
                      ],
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
