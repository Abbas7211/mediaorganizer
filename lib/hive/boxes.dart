import 'package:hive/hive.dart';

import 'models/media_item.dart';
import 'models/library_item.dart';
import 'models/studio_item.dart';
import 'models/studio_folder.dart';
import 'models/media_folder.dart';

late Box<MediaItem> downloadsBox;
late Box<dynamic> historyBox;
late Box<LibraryItem> libraryBox;
late Box<StudioItem> studioBox;
late Box<StudioFolder> studioFolderBox;

late Box<MediaFolder> mediaFolderBox;

Future<void> openHiveBoxes() async {
  historyBox = await Hive.openBox('history');
  downloadsBox = await Hive.openBox<MediaItem>('downloads');
  libraryBox = await Hive.openBox<LibraryItem>('library');
  studioBox = await Hive.openBox<StudioItem>('studio_items');
  studioFolderBox = await Hive.openBox<StudioFolder>('studio_folders');

  mediaFolderBox = await Hive.openBox<MediaFolder>('media_folders');
}
