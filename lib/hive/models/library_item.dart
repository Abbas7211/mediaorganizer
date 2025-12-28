import 'dart:io';
import 'package:hive/hive.dart';

part 'library_item.g.dart';

@HiveType(typeId: 1)
class LibraryItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String filePath;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  String? thumbnailPath;

  @HiveField(5)
  String? url;

  @HiveField(6)
  bool isFavorite;

  @HiveField(7)
  String? folderId;

  LibraryItem({
    required this.id,
    required this.title,
    required this.filePath,
    required this.createdAt,
    this.thumbnailPath,
    this.url,
    this.isFavorite = false,
    this.folderId,
  });

  String get displayTitle => title;

  String get format {
    final name = (url?.isNotEmpty == true) ? url! : title;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < name.length - 1) {
      return name.substring(dotIndex + 1).toUpperCase();
    }
    return 'MP4';
  }

  String get platform {
    if (url == null) return 'Original site';
    try {
      final host = Uri.parse(url!).host;
      if (host.contains('instagram')) return 'Instagram';
      if (host.contains('facebook')) return 'Facebook';
      if (host.contains('tiktok')) return 'TikTok';
      if (host.contains('youtube') || host.contains('youtu.be')) return 'YouTube';
      return host;
    } catch (_) {
      return 'Original site';
    }
  }

  int get sizeBytes {
    try {
      final f = File(filePath);
      if (!f.existsSync()) return 0;
      return f.lengthSync();
    } catch (_) {
      return 0;
    }
  }
}
