import 'package:flutter/material.dart';
import '../core/constants.dart';

class HowToDownloadScreen extends StatelessWidget {
  const HowToDownloadScreen({super.key});

  static const _steps = [
    _HowToStep(
      title: 'Search for or paste video link',
      imagePath: 'assets/images/How_To_Download_1.png',
    ),
    _HowToStep(
      title: 'Open the web page',
      imagePath: 'assets/images/How_To_Download_2.png',
    ),
    _HowToStep(
      title: 'Tap the button to download',
      imagePath: 'assets/images/How_To_Download_3.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('How to download'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _steps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          final step = _steps[i];
          return Container(
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.asset(
                    step.imagePath,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    '${i + 1}. ${step.title}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HowToStep {
  final String title;
  final String imagePath;
  const _HowToStep({required this.title, required this.imagePath});
}
