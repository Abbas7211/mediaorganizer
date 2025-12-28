import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../core/constants.dart';
import '../hive/models/media_item.dart';
import '../managers/download_manager.dart';
import '../widgets/download_card.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  bool _selectionMode = false;

  double _usedGb = 0.0;
  double _totalGb = 0.0;
  bool _storageLoaded = false;

  int get _selectedCount =>
      downloadManager.downloads.where((e) => e.isSelected).length;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    try {
      final (used, total) = await downloadManager.getStorageInfo();
      if (!mounted) return;
      setState(() {
        _usedGb = used;
        _totalGb = total;
        _storageLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _storageLoaded = true);
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (!_selectionMode) _selectionMode = true;

      final items = downloadManager.downloads;
      if (index < 0 || index >= items.length) return;

      items[index].isSelected = !items[index].isSelected;

      if (_selectedCount == 0) _selectionMode = false;
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        for (final item in downloadManager.downloads) {
          item.isSelected = false;
        }
      }
    });
  }

  void _selectAll() {
    setState(() {
      for (final item in downloadManager.downloads) {
        item.isSelected = true;
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text('Delete all?'),
        content: Text(
          'Delete $_selectedCount selected item(s)?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await downloadManager.removeSelectedDownloads();
      if (!mounted) return;
      setState(() => _selectionMode = false);
    }
  }

  Future<bool?> _confirmDeleteSingle(MediaItem item) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text('Remove download?'),
        content: Text(
          'Remove "${item.title}" from the list?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _openItem(MediaItem item) async {
    if (!item.isCompleted) return;

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

  String _formatTimeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final double usedFraction =
    (_totalGb > 0) ? (_usedGb / _totalGb).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_selectionMode ? '$_selectedCount Selected' : 'Downloads'),
        actions: [
          if (_selectionMode) ...[
            TextButton(
              onPressed: _selectAll,
              child: const Text('Select all', style: TextStyle(color: Colors.white)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelected,
            ),
          ] else ...[
            IconButton(
              tooltip: 'Select items',
              icon: const Icon(Icons.check_box_outlined),
              onPressed: _toggleSelectionMode,
            ),
          ],
        ],
      ),
      body: AnimatedBuilder(
        animation: downloadManager,
        builder: (context, _) {
          final items = downloadManager.downloads;

          return Column(
            children: [
              Expanded(
                child: items.isEmpty
                    ? const Center(
                  child: Text(
                    'No downloads yet.\nPaste a link on the Home page to start.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDeleteSingle(item),
                      onDismissed: (_) {
                        setState(() {
                          downloadManager.removeDownloadEntry(item);
                          if (_selectedCount == 0) _selectionMode = false;
                        });
                      },
                      background: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.only(right: 24),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: GestureDetector(
                        onLongPress: () => _toggleSelection(index),
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelection(index);
                          } else {
                            _openItem(item);
                          }
                        },
                        child: DownloadCard(
                          item: item,
                          timeAgoText: _formatTimeAgo(item.createdAt),
                        ),
                      ),
                    );
                  },
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: const BoxDecoration(
                  color: Color(0xFF101117),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smartphone, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: usedFraction,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(kAccentColor),
                            minHeight: 4,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _storageLoaded && _totalGb > 0
                                ? '${_usedGb.toStringAsFixed(2)} / ${_totalGb.toStringAsFixed(2)} GB used'
                                : 'Storage info unavailable',
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Private Folder',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
