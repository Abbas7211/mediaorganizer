import 'package:hive/hive.dart';

part 'media_folder.g.dart';

@HiveType(typeId: 4)
class MediaFolder extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  MediaFolder({required this.id, required this.name});
}
