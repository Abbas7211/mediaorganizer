import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../hive/models/studio_item.dart';

class StudioListTile extends StatelessWidget {
  const StudioListTile({
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: kAccentColor, width: 1.2) : null,
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: (thumb != null && thumb.isNotEmpty && File(thumb).existsSync())
                    ? Image.file(File(thumb), fit: BoxFit.cover)
                    : const Icon(Icons.play_arrow),
              ),
            ),
            if (selected)
              const Positioned(
                right: 0,
                bottom: 0,
                child: Icon(Icons.check_circle, color: kAccentColor, size: 18),
              ),
          ],
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: Text(sizeText, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ),
    );
  }
}
