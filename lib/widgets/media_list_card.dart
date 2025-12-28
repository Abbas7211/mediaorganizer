import 'dart:io';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../hive/models/library_item.dart';

class MediaListCard extends StatelessWidget {
  const MediaListCard({
    super.key,
    required this.item,
    required this.addedText,
    required this.selected,
    required this.onMore,
    required this.sizeText,
  });

  final LibraryItem item;
  final String addedText;
  final bool selected;
  final VoidCallback onMore;
  final String sizeText;

  @override
  Widget build(BuildContext context) {
    final thumb = item.thumbnailPath;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: kAccentColor, width: 1.2) : null,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: (thumb != null && thumb.isNotEmpty && File(thumb).existsSync())
                  ? Image.file(File(thumb), fit: BoxFit.cover)
                  : Container(
                color: Colors.black26,
                child: const Icon(Icons.play_circle_outline, size: 26),
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  addedText,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.format} • $sizeText',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: onMore,
            icon: const Icon(Icons.more_vert, size: 20),
          ),
        ],
      ),
    );
  }
}
