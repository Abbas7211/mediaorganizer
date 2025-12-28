import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../hive/models/media_item.dart';

class DownloadCard extends StatelessWidget {
  const DownloadCard({
    super.key,
    required this.item,
    required this.timeAgoText,
  });

  final MediaItem item;
  final String timeAgoText;

  @override
  Widget build(BuildContext context) {
    final bool selected = item.isSelected;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? kCardColor.withOpacity(0.6) : kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: kAccentColor.withOpacity(0.8), width: 1.3) : null,
        boxShadow: const [
          BoxShadow(
            blurRadius: 4,
            offset: Offset(0, 2),
            color: Colors.black54,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.isCompleted ? Icons.check_circle : Icons.downloading,
                color: kAccentColor,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                '${(item.progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: kAccentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 3,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(kAccentColor),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item.sizeMb.toStringAsFixed(2)} Mb',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    Text(
                      item.status,
                      style: TextStyle(
                        fontSize: 12,
                        color: item.isCompleted ? Colors.greenAccent : Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgoText,
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
