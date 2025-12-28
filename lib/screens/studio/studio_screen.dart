import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/constants.dart';
import '../../hive/boxes.dart';
import '../../hive/models/studio_item.dart';
import '../../managers/download_manager.dart';

import '../../widgets/studio/studio_grid_tile.dart';
import '../../widgets/studio/studio_list_tile.dart';
import 'studio_actions.dart';

enum StudioSortBy { name, date, size }
enum StudioViewMode { list, grid }

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final TextEditingController _search = TextEditingController();

  final Set<String> _selectedIds = <String>{};
  bool get _selectMode => _selectedIds.isNotEmpty;

  StudioSortBy _sortBy = StudioSortBy.date;
  bool _ascending = false;
  StudioViewMode _viewMode = StudioViewMode.list;

  int get _selectedCount => _selectedIds.length;

  List<StudioItem> get _selectedItems {
    final set = _selectedIds;
    return downloadManager.studioItems.where((e) => set.contains(e.id)).toList();
  }

  @override
  void dispose() {
    _search.dispose();
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

  // ---------- selection ----------
  void _clearSelection() => setState(() => _selectedIds.clear());

  void _toggleSelected(StudioItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  void _selectAllVisible(List<StudioItem> visible) {
    setState(() {
      for (final it in visible) {
        _selectedIds.add(it.id);
      }
    });
  }

  // ---------- filtering/sorting ----------
  List<StudioItem> _visibleItems() {
    final q = _search.text.trim().toLowerCase();

    var items = downloadManager.studioItems.where((it) {
      if (q.isEmpty) return true;
      return it.title.toLowerCase().contains(q);
    }).toList();

    int cmp(StudioItem a, StudioItem b) {
      switch (_sortBy) {
        case StudioSortBy.name:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case StudioSortBy.date:
          return a.createdAt.compareTo(b.createdAt);
        case StudioSortBy.size:
          return a.sizeBytes.compareTo(b.sizeBytes);
      }
    }

    items.sort((a, b) => _ascending ? cmp(a, b) : cmp(b, a));
    return items;
  }

  // ---------- open ----------
  Future<void> _openWith(StudioItem item) async {
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
        SnackBar(content: Text('Open failed: ${result.message}')),
      );
    }
  }

  // ---------- import videos ----------
  Future<void> _pickVideosIntoStudio() async {
    final perm = await Permission.videos.request();
    if (!perm.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied.')),
      );
      return;
    }

    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (res == null || res.files.isEmpty) return;

    final appDir = await getApplicationDocumentsDirectory();
    final studioDir = Directory(p.join(appDir.path, 'studio'));
    if (!await studioDir.exists()) await studioDir.create(recursive: true);

    for (final f in res.files) {
      final srcPath = f.path;
      if (srcPath == null) continue;

      final srcFile = File(srcPath);
      if (!await srcFile.exists()) continue;

      final fileName = p.basename(srcPath);
      final newId = 's_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      final destPath = p.join(studioDir.path, '${newId}_$fileName');

      await srcFile.copy(destPath);
      final thumb = await _generateStudioThumbnail(destPath, newId);
      final sizeBytes = await File(destPath).length();

      final item = StudioItem(
        id: newId,
        title: fileName,
        filePath: destPath,
        createdAt: DateTime.now(),
        sizeBytes: sizeBytes,
        sourceUrl: null,
        folderId: null,
        thumbnailPath: thumb,
      );

      await studioBox.put(item.id, item);
    }

    await downloadManager.loadStudioFromHive();
  }

  Future<String?> _generateStudioThumbnail(String videoPath, String id) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final created = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        timeMs: 1000,
      );
      if (created == null) return null;

      final thumbPath = p.join(dir.path, 'studio_thumb_$id.jpg');
      final f = File(created);
      if (await f.exists()) {
        await f.copy(thumbPath);
        try {
          await f.delete();
        } catch (_) {}
        return thumbPath;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ---------- create folder (Media List folder) ----------
  Future<void> _createMediaFolderDialog() async {
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

  // ---------- move ----------
  Future<String?> _pickMediaFolderForMove() async {
    // returns:
    //   null  => Media Root
    //   'mf_x' => that folder
    //   '__CANCEL__' => dismissed (do nothing)

    final res = await showModalBottomSheet<String?>(
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
              title: const Text('Media Root'),
              onTap: () => Navigator.pop(ctx, null), // Media Root
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

    // If user dismisses by tapping outside / swipe down
    if (res == null) {
    }
    return res;
  }


  Future<void> _moveMenu(List<StudioItem> items) async {
    const moveToMediaList = '__MOVE_TO_MEDIA_LIST__';

    final choice = await showModalBottomSheet<String>(
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
              onTap: () => Navigator.pop(ctx, 'MEDIA_ROOT'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.move_to_inbox_outlined),
              title: const Text('Move to Media List'),
              onTap: () => Navigator.pop(ctx, moveToMediaList),
            ),
          ],
        ),
      ),
    );

    // dismissed -> do nothing
    if (choice == null) return;

    // Move to Media List Root
    if (choice == 'MEDIA_ROOT') {
      await downloadManager.moveStudioItemsToMediaListFolder(
        items: items,
        mediaFolderId: null, // Media Root
      );
      _clearSelection();
      return;
    }

    // Move to Media List, open folder picker
    if (choice == moveToMediaList) {
      final picked = await _pickMediaFolderForMove();

      // If user picked a folder id, move directly
      if (picked != null) {
        await downloadManager.moveStudioItemsToMediaListFolder(
          items: items,
          mediaFolderId: picked,
        );
        _clearSelection();
        return;
      }

      if (!mounted) return;
      final confirmRoot = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          backgroundColor: kCardColor,
          title: const Text('Move to Media Root?'),
          content: const Text(
            'Move selected item(s) to Media Root?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Move')),
          ],
        ),
      );

      if (confirmRoot == true) {
        await downloadManager.moveStudioItemsToMediaListFolder(
          items: items,
          mediaFolderId: null, // Media Root
        );
        _clearSelection();
      }
    }
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
      await downloadManager.renameStudioItem(item, newName);
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
      await downloadManager.deleteStudioItems(_selectedItems);
      _clearSelection();
    }
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
              child: DropdownButton<StudioSortBy>(
                value: _sortBy,
                dropdownColor: kCardColor,
                iconEnabledColor: Colors.white70,
                items: const [
                  DropdownMenuItem(value: StudioSortBy.name, child: Text('Name')),
                  DropdownMenuItem(value: StudioSortBy.date, child: Text('Date')),
                  DropdownMenuItem(value: StudioSortBy.size, child: Text('Size')),
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
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: AnimatedBuilder(
        animation: downloadManager,
        builder: (context, _) {
          final visible = _visibleItems();
          final totalBytes = visible.fold<int>(0, (sum, it) => sum + it.sizeBytes);

          return Scaffold(
            backgroundColor: kBgColor,
            appBar: AppBar(
              backgroundColor: kBgColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBack,
              ),
              title: _selectMode
                  ? Text('Select items ($_selectedCount)')
                  : const Text('Studio'),
              actions: [
                if (_selectMode) ...[
                  TextButton(
                    onPressed: () => _selectAllVisible(visible),
                    child: const Text('All', style: TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: _clearSelection,
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                ] else ...[
                  IconButton(
                    tooltip: 'Import videos',
                    icon: const Icon(Icons.folder_open_outlined),
                    onPressed: _pickVideosIntoStudio,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) async {
                      if (v == 'view') {
                        setState(() {
                          _viewMode = _viewMode == StudioViewMode.list ? StudioViewMode.grid : StudioViewMode.list;
                        });
                      }
                      if (v == 'folder') {
                        await _createMediaFolderDialog(); // creates Media List folder
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'view', child: Text('View')),
                      PopupMenuItem(value: 'folder', child: Text('Create Folder')),
                    ],
                  ),
                ],
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search',
                      ),
                      onChanged: (_) => setState(() {}),
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
                      '${visible.length} videos (${_fmtBytes(totalBytes)})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Sort bar
                  _sortBar(),

                  const SizedBox(height: 14),

                  Expanded(
                    child: (_viewMode == StudioViewMode.grid)
                        ? GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 180,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (ctx, i) {
                        final item = visible[i];
                        final selected = _selectedIds.contains(item.id);

                        return StudioGridTile(
                          item: item,
                          subtitle: _fmtDate(item.createdAt),
                          sizeText: _fmtBytes(item.sizeBytes),
                          selected: selected,
                          onTap: () {
                            if (_selectMode) {
                              _toggleSelected(item);
                            } else {
                              _openWith(item);
                            }
                          },
                          onLongPress: () {
                            setState(() => _selectedIds.add(item.id));
                          },
                        );
                      },

                    )
                        : ListView(
                      children: [
                        if (visible.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(
                              child: Text('No videos here.', style: TextStyle(color: Colors.white60)),
                            ),
                          )
                        else
                          ...visible.map((item) {
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
                              child: Container(
                                decoration: BoxDecoration(
                                  border: selected ? Border.all(color: kAccentColor, width: 1.2) : null,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: StudioListTile(
                                  item: item,
                                  subtitle: _fmtDate(item.createdAt),
                                  sizeText: _fmtBytes(item.sizeBytes),
                                  selected: selected,
                                  onTap: () {
                                    if (_selectMode) {
                                      _toggleSelected(item);
                                    } else {
                                      _openWith(item);
                                    }
                                  },
                                  onLongPress: () => setState(() => _selectedIds.add(item.id)),
                                ),
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
                            _bottomAction('Move', Icons.drive_file_move, () => _moveMenu(_selectedItems)),
                            _bottomAction('Details', Icons.info_outline, () {
                              if (_selectedItems.length == 1) {
                                StudioActions.showDetails(context, _selectedItems.first);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Select 1 item to view details.')),
                                );
                              }
                            }),
                            _bottomAction('Rename', Icons.edit, _renameSelected),
                            _bottomAction('Delete', Icons.delete_outline, _deleteSelected),
                            _bottomAction('Open With', Icons.open_in_new, () {
                              if (_selectedItems.length == 1) {
                                _openWith(_selectedItems.first);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Select 1 item to open.')),
                                );
                              }
                            }),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
