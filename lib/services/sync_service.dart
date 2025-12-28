import 'package:cloud_firestore/cloud_firestore.dart';

import '../hive/boxes.dart';
import '../hive/models/library_item.dart';
import '../hive/models/media_folder.dart';

import '../core/history_notifier.dart';
import '../core/constants.dart';

class SyncService {
  final FirebaseFirestore _db;

  SyncService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _foldersCol(String uid) =>
      _userDoc(uid).collection('mediaFolders');

  CollectionReference<Map<String, dynamic>> _itemsCol(String uid) =>
      _userDoc(uid).collection('libraryItems');

  // ---------------- HISTORY (Hive-backed) ----------------

  List<String> _readHistoryFromHive() {
    final stored = historyBox.get('entries');
    if (stored is List) return stored.cast<String>();
    return <String>[];
  }

  Future<void> _writeHistoryToHive(List<String> history) async {
    await historyBox.put('entries', List<String>.from(history));
  }

  // ---------------- BATCH HELPERS ----------------
  // Firestore batch limit is 500 operations -> chunk safely.
  Future<void> _commitInChunks(List<void Function(WriteBatch batch)> ops) async {
    const limit = 450; // keep safe margin
    for (var i = 0; i < ops.length; i += limit) {
      final batch = _db.batch();
      final end = (i + limit < ops.length) ? i + limit : ops.length;
      for (var j = i; j < end; j++) {
        ops[j](batch);
      }
      await batch.commit();
    }
  }

  // ---------------- PUBLIC API ----------------

  /// Upload local metadata (folders, items, web history, lastSyncAt).
  Future<void> syncAll(String uid) async {
    final ops = <void Function(WriteBatch)>[];

    // 1) user meta + last sync + web history
    final history = _readHistoryFromHive();

    ops.add((b) {
      b.set(
        _userDoc(uid),
        {
          'lastSyncAt': FieldValue.serverTimestamp(),
          'webHistory': history,
        },
        SetOptions(merge: true),
      );
    });

    // 2) folders
    for (final folder in mediaFolderBox.values) {
      ops.add((b) {
        b.set(
          _foldersCol(uid).doc(folder.id),
          {
            'id': folder.id,
            'name': folder.name,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
    }

    // 3) library items (metadata only)
    for (final item in libraryBox.values) {
      ops.add((b) {
        b.set(
          _itemsCol(uid).doc(item.id),
          {
            'id': item.id,
            'title': item.title,
            'createdAt': Timestamp.fromDate(item.createdAt),
            'url': item.url,
            'isFavorite': item.isFavorite,
            'folderId': item.folderId,
          },
          SetOptions(merge: true),
        );
      });
    }

    await _commitInChunks(ops);
  }

  /// Download metadata from cloud and merge into local Hive.
  Future<void> retrieveAll(String uid) async {
    // 1) folders
    final foldersSnap = await _foldersCol(uid).get();
    for (final doc in foldersSnap.docs) {
      final d = doc.data();
      final id = (d['id'] ?? doc.id).toString();
      final name = (d['name'] ?? 'Folder').toString();

      final existing = mediaFolderBox.get(id);
      if (existing != null) {
        existing.name = name;
        await existing.save();
      } else {
        final folder = MediaFolder(id: id, name: name);
        await mediaFolderBox.put(folder.id, folder);
      }
    }

    // 2) items metadata, create/merge placeholders
    final itemsSnap = await _itemsCol(uid).get();
    for (final doc in itemsSnap.docs) {
      final d = doc.data();

      final id = (d['id'] ?? doc.id).toString();
      final title = (d['title'] ?? 'Video').toString();
      final url = d['url']?.toString();
      final isFav = (d['isFavorite'] == true);
      final folderId = d['folderId']?.toString();

      DateTime createdAt = DateTime.now();
      final ts = d['createdAt'];
      if (ts is Timestamp) createdAt = ts.toDate();

      final existing = libraryBox.get(id);
      if (existing != null) {
        // Keep local filePath + thumbnailPath intact.
        existing
          ..title = title
          ..url = url
          ..isFavorite = isFav
          ..folderId = folderId
          ..createdAt = createdAt;
        await existing.save();
      } else {
        final placeholder = LibraryItem(
          id: id,
          title: title,
          filePath: '',
          createdAt: createdAt,
          thumbnailPath: null,
          url: url,
          isFavorite: isFav,
          folderId: folderId,
        );
        await libraryBox.put(placeholder.id, placeholder);
      }
    }

    // 3) history
    final userSnap = await _userDoc(uid).get();
    final data = userSnap.data();

    final cloudHistory = data?['webHistory'];
    if (cloudHistory is List) {
      final history = cloudHistory.map((e) => e.toString()).toList();

      /// write to Hive
      await HistoryNotifier.I.writeToHive(history);

      /// notify BrowserScreen to reload from Hive
      HistoryNotifier.I.bump();
    }
  }

  /// delete subcollections in chunks
  Future<void> deleteCloudData(String uid) async {
    Future<void> _deleteCollection(CollectionReference col) async {
      while (true) {
        final snap = await col.limit(200).get();
        if (snap.docs.isEmpty) break;

        final batch = _db.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }

    await _deleteCollection(_foldersCol(uid));
    await _deleteCollection(_itemsCol(uid));

    // clear fields on user doc
    await _userDoc(uid).set(
      {
        'lastSyncAt': FieldValue.delete(),
        'webHistory': <String>[],
      },
      SetOptions(merge: true),
    );
  }


  Stream<DateTime?> lastSyncStream(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final ts = snap.data()?['lastSyncAt'];
      if (ts is Timestamp) return ts.toDate();
      return null;
    });
  }
}
