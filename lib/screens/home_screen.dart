import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../widgets/home_card_button.dart';
import 'browser_screen.dart';
import 'download_screen.dart';
import 'how_to_download_screen.dart';
import 'favorites_screen.dart';
import 'media_list_screen.dart';
import 'settings_screen.dart';
import 'studio/studio_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _bannerPath = 'assets/images/home_banner.png';

  void _openBrowser() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BrowserScreen(initialUrl: ''),
      ),
    );
  }

  void _onBottomNavTap(int index) {
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FavoritesScreen()),
      );
    } else if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    }
    // index == 0 is Home, do nothing
  }

  void _openMediaList() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MediaListScreen()),
    );
  }

  void _openDownloads() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DownloadScreen()),
    );
  }

  void _openStudio() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudioScreen()),
    );
  }

  void _openHowToDownload() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HowToDownloadScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              const _HomeBanner(imagePath: _bannerPath),
              const SizedBox(height: 24),

              // Search / paste URL bar
              GestureDetector(
                onTap: _openBrowser,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: kCardColor,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.link, size: 26, color: Colors.white60),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search or paste URL',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Cards
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: HomeCardButton(
                            icon: Icons.photo_library_outlined,
                            label: 'Media List',
                            onTap: _openMediaList,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: HomeCardButton(
                            icon: Icons.download_outlined,
                            label: 'Download',
                            onTap: _openDownloads,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: HomeCardButton(
                            icon: Icons.folder_open_outlined,
                            label: 'Studio',
                            onTap: _openStudio,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: HomeCardButton(
                            icon: Icons.help_outline,
                            label: 'How to\ndownload',
                            onTap: _openHowToDownload,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      /// Bottom navigation
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF111217),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
        currentIndex: 0,
        onTap: _onBottomNavTap,
      ),
    );
  }
}

class _HomeBanner extends StatelessWidget {
  const _HomeBanner({
    required this.imagePath,
  });

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 290,
      width: double.infinity,
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1.4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 60,
                color: Colors.white54,
              ),
            );
          },
        ),
      ),
    );
  }
}
