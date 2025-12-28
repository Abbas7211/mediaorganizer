import '../../hive/models/studio_item.dart';

enum StudioSortBy { name, date, size }
enum StudioViewMode { list, grid }

class StudioStateHelpers {
  static String fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  static String fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  static List<StudioItem> filterAndSort({
    required List<StudioItem> allItems,
    required String query,
    required String? currentFolderId,
    required StudioSortBy sortBy,
    required bool ascending,
  }) {
    final q = query.trim().toLowerCase();

    final filtered = allItems.where((it) {
      final sameFolder = (currentFolderId == null)
          ? (it.folderId == null)
          : (it.folderId == currentFolderId);

      if (!sameFolder) return false;
      if (q.isEmpty) return true;
      return it.title.toLowerCase().contains(q);
    }).toList();

    int cmp(StudioItem a, StudioItem b) {
      switch (sortBy) {
        case StudioSortBy.name:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case StudioSortBy.date:
          return a.createdAt.compareTo(b.createdAt);
        case StudioSortBy.size:
          return a.sizeBytes.compareTo(b.sizeBytes);
      }
    }

    filtered.sort((a, b) => ascending ? cmp(a, b) : cmp(b, a));
    return filtered;
  }
}
