import 'package:hive/hive.dart';

part 'studio_item.g.dart';

@HiveType(typeId: 3)
class StudioItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String filePath;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  int sizeBytes;

  @HiveField(5)
  String? sourceUrl;

  @HiveField(6)
  String? folderId;

  @HiveField(7)
  String? thumbnailPath;

  @HiveField(8)
  bool isSelected;

  StudioItem({
    required this.id,
    required this.title,
    required this.filePath,
    required this.createdAt,
    required this.sizeBytes,
    this.sourceUrl,
    this.folderId,
    this.thumbnailPath,
    this.isSelected = false,
  });
}
