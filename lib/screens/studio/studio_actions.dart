import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/constants.dart';
import '../../hive/boxes.dart';
import '../../hive/models/studio_folder.dart';
import '../../hive/models/studio_item.dart';
import '../../managers/download_manager.dart';
import 'studio_state.dart';

class StudioActions {
  static Future<void> openWith(BuildContext context, StudioItem item) async {
    final file = File(item.filePath);
    if (!await file.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found on device.')),
      );
      return;
    }

    final result = await OpenFilex.open(item.filePath);
    if (!context.mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Open failed: ${result.message}')),
      );
    }
  }

  static Future<void> pickVideosIntoStudio({
    required BuildContext context,
    required String? currentFolderId,
  }) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (res == null || res.files.isEmpty) return;

    final appDir = await getApplicationDocumentsDirectory();
    final studioDir = Directory(p.join(appDir.path, 'studio'));
    if (!await studioDir.exists()) {
      await studioDir.create(recursive: true);
    }

    for (final f in res.files) {
      final srcPath = f.path;
      if (srcPath == null) continue;

      final srcFile = File(srcPath);
      if (!await srcFile.exists()) continue;

      final fileName = p.basename(srcPath);
      final newId =
          's_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
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
        folderId: currentFolderId,
        thumbnailPath: thumb,
      );

      await studioBox.put(item.id, item);
    }

    await downloadManager.loadStudioFromHive();
  }

  static Future<String?> _generateStudioThumbnail(String videoPath, String id) async {
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

  static Future<void> createFolderDialog(BuildContext context) async {
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
      final f = StudioFolder(
        id: 'f_${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
      );
      await studioFolderBox.put(f.id, f);
      await downloadManager.loadStudioFromHive();
    }
  }

  static Future<void> showDetails(BuildContext context, StudioItem item) async {
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
                      child: (thumb != null && File(thumb).existsSync())
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
                Text('Date & time: ${StudioStateHelpers.fmtDate(item.createdAt)}',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text('Size: ${StudioStateHelpers.fmtBytes(item.sizeBytes)}',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text('Source URL: ${item.sourceUrl ?? "—"}',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> moveToFolder(
      BuildContext context,
      List<StudioItem> items,
      ) async {
    final chosen = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Root'),
                onTap: () => Navigator.pop(ctx, null),
              ),
              const Divider(height: 1),
              ...downloadManager.studioFolders.map((f) {
                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(f.name),
                  onTap: () => Navigator.pop(ctx, f.id),
                );
              }),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );

    for (final it in items) {
      it.folderId = chosen;
      await it.save();
    }
    await downloadManager.loadStudioFromHive();
  }

  static Future<void> renameSelected(
      BuildContext context,
      List<StudioItem> items,
      ) async {
    if (items.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select 1 item to rename.')),
      );
      return;
    }

    final item = items.first;
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
      item.title = newName.trim();
      await item.save();
      await downloadManager.loadStudioFromHive();
    }
  }

  static Future<void> deleteSelected(
      BuildContext context,
      List<StudioItem> items,
      ) async {
    if (items.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text('Delete'),
        content: Text('Delete ${items.length} item(s)?',
            style: const TextStyle(color: Colors.white70)),
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
      for (final it in items) {
        try {
          final f = File(it.filePath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
        await studioBox.delete(it.id);
      }
      await downloadManager.loadStudioFromHive();
    }
  }
}
