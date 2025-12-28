import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../hive/models/studio_item.dart';

class StudioGridTile extends StatelessWidget {
  const StudioGridTile({
    super.key,
    required this.item,
    required this.subtitle,
    required this.sizeText,
    required this.onTap,
    required this.onLongPress,
    required this.selected,
  });

  final StudioItem item;
  final String subtitle;
  final String sizeText;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final thumb = item.thumbnailPath;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(14),
          border: selected ? Border.all(color: kAccentColor, width: 1.2) : null,
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: double.infinity,
                  child: (thumb != null && thumb.isNotEmpty && File(thumb).existsSync())
                      ? Image.file(File(thumb), fit: BoxFit.cover)
                      : const Icon(Icons.play_circle_outline, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 2),
            Text(sizeText, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
