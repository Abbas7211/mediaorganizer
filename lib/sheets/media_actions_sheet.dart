import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../hive/models/library_item.dart';
import '../managers/download_manager.dart';
import '../screens/browser_screen.dart';

Future<void> showMediaActionsSheet(BuildContext context, LibraryItem item) async {
  showModalBottomSheet(
    context: context,
    backgroundColor: kCardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            // AI Features
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('AI Features'),
              onTap: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI Features will be implemented later.')),
                );
              },
            ),
            const Divider(height: 1),

            // Favorite toggle
            ListTile(
              leading: Icon(
                item.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: item.isFavorite ? Colors.pinkAccent : Colors.white70,
              ),
              title: Text(item.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
              onTap: () {
                Navigator.of(ctx).pop();
                downloadManager.toggleFavorite(item);
              },
            ),
            const Divider(height: 1),

            // Save to Studio
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Save to Studio'),
              onTap: () async {
                Navigator.of(ctx).pop();

                final path = item.filePath.trim();
                if (path.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("This is cloud metadata only (no file on device).")),
                  );
                  return;
                }

                await downloadManager.saveLibraryItemToStudio(item);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved to Studio')),
                );
              },
            ),
            const Divider(height: 1),

            // Copy URL
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy URL'),
              onTap: () {
                Navigator.of(ctx).pop();
                final u = item.url ?? '';
                if (u.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No URL available')),
                  );
                  return;
                }
                Clipboard.setData(ClipboardData(text: u));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL copied')),
                );
              },
            ),
            const Divider(height: 1),

            // Opens BrowserScreen
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text('View on ${item.platform}'),
              onTap: () {
                Navigator.of(ctx).pop();
                final u = item.url ?? '';
                if (u.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No URL available')),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BrowserScreen(initialUrl: u)),
                );
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
