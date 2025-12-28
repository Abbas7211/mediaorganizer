import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:storage_info/storage_info.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../hive/boxes.dart';
import '../hive/models/media_item.dart';
import '../hive/models/library_item.dart';
import '../hive/models/studio_item.dart';
import '../hive/models/studio_folder.dart';
import '../hive/models/media_folder.dart';


class DownloadManager extends ChangeNotifier {
  final Dio _dio = Dio();

  //state
  final List<MediaItem> _downloads = [];
  final List<LibraryItem> _library = [];
  final List<StudioItem> _studioItems = [];
  final List<StudioFolder> _studioFolders = [];
  final List<MediaFolder> _mediaFolders = [];


  List<MediaItem> get downloads => _downloads;
  List<LibraryItem> get libraryItems => List.unmodifiable(_library);

  List<LibraryItem> get favoriteItems =>
      _library.where((m) => m.isFavorite).toList();

  List<StudioItem> get studioItems => List.unmodifiable(_studioItems);
  List<StudioFolder> get studioFolders => List.unmodifiable(_studioFolders);
  List<MediaFolder> get mediaFolders => List.unmodifiable(_mediaFolders);

  Future<void> loadFromHive() async {
    _downloads
      ..clear()
      ..addAll(downloadsBox.values);

    _library
      ..clear()
      ..addAll(libraryBox.values);

    _mediaFolders
      ..clear()
      ..addAll(mediaFolderBox.values);

    _downloads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _library.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _mediaFolders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    notifyListeners();
  }


  Future<(double usedGb, double totalGb)> getStorageInfo() async {
    try {
      final storage = StorageInfo();
      final double totalGb = await storage.getStorageTotalSpace(SpaceUnit.GB);
      final double freeGb = await storage.getStorageFreeSpace(SpaceUnit.GB);
      if (totalGb <= 0) return (0.0, 0.0);
      final double usedGb = totalGb - freeGb;
      return (usedGb, totalGb);
    } catch (_) {
      return (0.0, 0.0);
    }
  }

  Future<void> startRealDownload({
    required BuildContext context,
    required String videoUrl,
  }) async {
    final uri = Uri.parse(videoUrl);

    String fileName;
    if (uri.pathSegments.isNotEmpty) {
      fileName = uri.pathSegments.last;
      if (!fileName.contains('.')) fileName = '$fileName.mp4';
    } else {
      fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    }

    final dir = await getApplicationDocumentsDirectory();
    final savePath = p.join(dir.path, fileName);

    final download = MediaItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: fileName,
      sizeMb: 0,
      filePath: savePath,
      progress: 0.0,
      status: 'Starting',
      url: videoUrl,
    );

    _downloads.insert(0, download);
    await downloadsBox.put(download.id, download);
    notifyListeners();

    try {
      await _dio.download(
        videoUrl,
        savePath,
        onReceiveProgress: (received, total) {
          download.downloadedBytes = received;
          download.totalBytes = total;

          if (total > 0) {
            download.progress = received / total;
            download.sizeMb = total / (1024 * 1024);
          }

          download.status = 'Downloading';
          downloadsBox.put(download.id, download);
          notifyListeners();
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      download.status = 'Downloaded';
      download.progress = 1.0;
      await downloadsBox.put(download.id, download);
      notifyListeners();

      final mediaId = 'm_${download.id}';
      final thumb = await _generateThumbnail(savePath, mediaId);

      final libItem = LibraryItem(
        id: mediaId,
        title: fileName,
        filePath: savePath,
        createdAt: DateTime.now(),
        thumbnailPath: thumb,
        url: videoUrl,
      );

      _library.insert(0, libItem);
      await libraryBox.put(libItem.id, libItem);
      notifyListeners();
    } catch (_) {
      download.status = 'Failed';
      download.progress = 0.0;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed.')),
        );
      }
    }
  }

  Future<String?> _generateThumbnail(String videoPath, String mediaId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final thumbPath = p.join(dir.path, 'thumb_$mediaId.jpg');

      final created = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        timeMs: 1000,
      );

      if (created == null) return null;

      final f = File(created);
      if (await f.exists()) {
        await f.copy(thumbPath);
        try {
          await f.delete();
        } catch (_) {}
      }
      return thumbPath;
    } catch (_) {
      return null;
    }
  }

  Future<void> removeDownloadEntry(MediaItem item) async{
    _downloads.removeWhere((d) => d.id == item.id);
    await downloadsBox.delete(item.id);
    notifyListeners();
  }

  Future<void> removeSelectedDownloads() async {
    final selected = _downloads.where((d) => d.isSelected).toList();

    for (final item in selected) {
      try {
        await item.delete();
      } catch (_) {}
    }

    _downloads.removeWhere((d) => d.isSelected);
    notifyListeners();
  }

  Future<void> toggleFavorite(LibraryItem item) async {
    item.isFavorite = !item.isFavorite;
    await item.save();
    notifyListeners();
  }

  Future<void> renameItem(LibraryItem item, String newName) async {
    item.title = newName;
    await item.save();
    notifyListeners();
  }

  Future<void> removeMedia(LibraryItem item) async{
    _library.removeWhere((m) => m.id == item.id);
    await libraryBox.delete(item.id);
    notifyListeners();
  }

  Future<void> loadStudioFromHive() async {
    _studioItems
      ..clear()
      ..addAll(studioBox.values);
    _studioFolders
      ..clear()
      ..addAll(studioFolderBox.values);

    _studioItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Future<void> createStudioFolder(String name) async {
    final f = StudioFolder(
      id: 'f_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
    );
    await studioFolderBox.put(f.id, f);
    await loadStudioFromHive();
  }

  Future<void> renameStudioItem(StudioItem item, String newName) async {
    item.title = newName.trim();
    await item.save();
    await loadStudioFromHive();
  }

  Future<void> deleteStudioItems(List<StudioItem> items) async {
    for (final it in items) {
      try {
        final f = File(it.filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      await studioBox.delete(it.id);
    }
    await loadStudioFromHive();
  }

  Future<void> moveStudioItemsToFolder(List<StudioItem> items, String? folderId) async {
    for (final it in items) {
      it.folderId = folderId;
      await it.save();
    }
    await loadStudioFromHive();
  }

  Future<void> createMediaFolder(String name) async {
    final f = MediaFolder(
      id: 'mf_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
    );
    await mediaFolderBox.put(f.id, f);
    await loadFromHive();
  }

  Future<void> renameMediaFolder(MediaFolder folder, String newName) async {
    folder.name = newName.trim();
    await folder.save();
    await loadFromHive();
  }

  Future<void> deleteMediaFolder(MediaFolder folder) async {
    // Move all items to Root before deleting folder (safe behavior)
    final items = _library.where((x) => x.folderId == folder.id).toList();
    for (final it in items) {
      it.folderId = null;
      await it.save();
    }
    await mediaFolderBox.delete(folder.id);
    await loadFromHive();
  }

  int mediaFolderCount(String folderId) {
    return _library.where((x) => x.folderId == folderId).length;
  }

  Future<void> moveLibraryItemsToFolder(List<LibraryItem> items, String? folderId) async {
    for (final it in items) {
      it.folderId = folderId;
      await it.save();
    }
    await loadFromHive();
  }

  Future<void> moveStudioItemsToMediaListFolder({
    required List<StudioItem> items,
    required String? mediaFolderId,
  }) async {
    for (final st in items) {
      final newId =
          'l_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}_${st.id}';

      final lib = LibraryItem(
        id: newId,
        title: st.title,
        filePath: st.filePath,
        createdAt: st.createdAt,
        thumbnailPath: st.thumbnailPath,
        url: st.sourceUrl,
        isFavorite: false,
        folderId: mediaFolderId,
      );

      await libraryBox.put(lib.id, lib);

      await studioBox.delete(st.id);
    }

    await loadFromHive();
    await loadStudioFromHive();
  }

  Future<void> saveLibraryItemToStudio(LibraryItem item) async {
    final src = File(item.filePath);
    if (!await src.exists()) return;

    final appDir = await getApplicationDocumentsDirectory();
    final studioDir = Directory(p.join(appDir.path, 'studio'));
    if (!await studioDir.exists()) await studioDir.create(recursive: true);

    final newId = 's_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final destPath = p.join(studioDir.path, '${newId}_${p.basename(item.filePath)}');

    await src.copy(destPath);

    final thumb = await _generateThumbnail(destPath, newId);
    final sizeBytes = await File(destPath).length();

    final st = StudioItem(
      id: newId,
      title: item.title,
      filePath: destPath,
      createdAt: DateTime.now(),
      sizeBytes: sizeBytes,
      sourceUrl: item.url,
      folderId: null,
      thumbnailPath: thumb,
    );

    await studioBox.put(st.id, st);
    await loadStudioFromHive();
  }


}

final DownloadManager downloadManager = DownloadManager();
