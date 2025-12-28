import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/constants.dart';
import 'core/history_notifier.dart';
import 'hive/boxes.dart';
import 'hive/models/media_item.dart';
import 'hive/models/library_item.dart';
import 'hive/models/studio_folder.dart';
import 'hive/models/studio_item.dart';
import 'hive/models/media_folder.dart';

import 'managers/download_manager.dart';
import 'screens/home_screen.dart';
import 'screens/browser_screen.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();

  // Register adapters
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(MediaItemAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(LibraryItemAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(StudioFolderAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(StudioItemAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(MediaFolderAdapter());

  // Open boxes
  historyBox = await Hive.openBox('history');
  downloadsBox = await Hive.openBox<MediaItem>('downloads');
  libraryBox = await Hive.openBox<LibraryItem>('library');
  studioBox = await Hive.openBox<StudioItem>('studio_items');
  studioFolderBox = await Hive.openBox<StudioFolder>('studio_folders');
  mediaFolderBox = await Hive.openBox<MediaFolder>('media_folders');

  // Load history list into memory
  final history = HistoryNotifier.I.readFromHive();
  searchHistory
    ..clear()
    ..addAll(history);


  await downloadManager.loadFromHive();
  await downloadManager.loadStudioFromHive();

  runApp(const MediaOrganizerApp());
}


class MediaOrganizerApp extends StatelessWidget {
  const MediaOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Media Organizer',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBgColor,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
      routes: {
        '/browser': (_) => const BrowserScreen(initialUrl: ''),
      },
    );
  }
}
