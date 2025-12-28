import 'package:hive/hive.dart';

part 'studio_folder.g.dart';

@HiveType(typeId: 2)
class StudioFolder extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  StudioFolder({required this.id, required this.name});
}
