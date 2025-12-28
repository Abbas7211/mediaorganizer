import 'package:hive/hive.dart';

part 'media_item.g.dart';

@HiveType(typeId: 0)
class MediaItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  double sizeMb;

  @HiveField(3)
  String filePath;

  @HiveField(4)
  double progress;

  @HiveField(5)
  String status;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  String? url;

  @HiveField(8)
  int downloadedBytes;

  @HiveField(9)
  int totalBytes;

  @HiveField(10)
  bool isSelected;

  @HiveField(11)
  bool isFavorite;

  MediaItem({
    required this.id,
    required this.title,
    required this.sizeMb,
    required this.filePath,
    this.progress = 0.0,
    this.status = 'Starting',
    DateTime? createdAt,
    this.url,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.isSelected = false,
    this.isFavorite = false,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCompleted => status == 'Downloaded' && progress >= 1.0;

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
}
