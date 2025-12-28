import 'dart:math';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/constants.dart';
import '../core/history_notifier.dart';
import '../hive/boxes.dart';
import '../managers/download_manager.dart';

// Shared history list
final List<String> searchHistory = [];

void addToHistory(String query) {
  final q = query.trim();
  if (q.isEmpty) return;

  searchHistory.remove(q);
  searchHistory.insert(0, q);

  if (searchHistory.length > 10) {
    searchHistory.removeLast();
  }

  historyBox.put('entries', List<String>.from(searchHistory));
  HistoryNotifier.I.bump();
}

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.initialUrl});
  final String initialUrl;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _webController;
  late final VoidCallback _historyListener;

  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  bool _showHistory = false;

  bool _canGoBack = false;
  bool _canGoForward = false;



  // Keep what the user typed
  String _lastUserInput = '';

  bool _looksLikeMediaFile(String url) {
    final lower = url.toLowerCase();
    if (!(lower.startsWith('http://') || lower.startsWith('https://'))) return false;
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.h5p');
  }

  String _cleanDisplayUrl(String? url) {
    if (url == null) return '';
    if (url == 'about:blank') return '';
    return url;
  }

  void _dismissInput() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) setState(() => _showHistory = false);
  }



  void _loadHistoryFromHive() {
    final stored = historyBox.get('entries');
    final list = (stored is List)
        ? stored.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList()
        : <String>[];

    searchHistory
      ..clear()
      ..addAll(list);

    if (mounted) setState(() {});
  }

  Future<void> _refreshNavState() async {
    final b = await _webController.canGoBack();
    final f = await _webController.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = b;
      _canGoForward = f;
    });
  }

  @override
  void initState() {
    super.initState();

    // history notifier listener
    _loadHistoryFromHive();
    _historyListener = () => _loadHistoryFromHive();
    HistoryNotifier.I.revision.addListener(_historyListener);

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36",
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _isLoading = true);
          },
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() => _isLoading = false);

            // Update the address bar from currentUrl when NOT typing
            if (!_focusNode.hasFocus) {
              final current = await _webController.currentUrl();
              final cleaned = _cleanDisplayUrl(current);
              _urlController.text = cleaned;
              _urlController.selection = TextSelection.collapsed(offset: _urlController.text.length);
            }

            await _refreshNavState();
          },
          onUrlChange: (change) async {
            // never overwrite while focused
            if (!_focusNode.hasFocus) {
              _urlController.text = _cleanDisplayUrl(change.url);
              _urlController.selection = TextSelection.collapsed(offset: _urlController.text.length);
            }
            await _refreshNavState();
          },
        ),
      );

    // Load initial
    final trimmed = widget.initialUrl.trim();
    if (trimmed.isNotEmpty && trimmed != ' ') {
      _urlController.text = trimmed;
      _lastUserInput = trimmed;
      _loadUrl(trimmed, fromUser: false);
    }

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _showHistory = true);

        // keep what user had typed
        _lastUserInput = _urlController.text;

        // select all
        _urlController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _urlController.text.length,
        );
      } else {
        // when leaving focus, hide history
        if (mounted) setState(() => _showHistory = false);
      }
    });
  }

  @override
  void dispose() {
    HistoryNotifier.I.revision.removeListener(_historyListener);
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _buildUrlFromInput(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'https://www.google.com/';

    final hasScheme = text.startsWith('http://') || text.startsWith('https://');
    final looksLikeUrl = text.contains('.') && !text.contains(' ');

    if (looksLikeUrl) return hasScheme ? text : 'https://$text';

    final encoded = Uri.encodeQueryComponent(text);
    return 'https://www.google.com/search?q=$encoded';
  }

  void _loadUrl(String value, {bool fromUser = true}) {
    final text = value.trim();
    if (text.isEmpty) return;

    if (fromUser) addToHistory(text);

    final finalUrl = _buildUrlFromInput(text);

    setState(() {
      _showHistory = false;
      _isLoading = true;
    });

    FocusManager.instance.primaryFocus?.unfocus();

    _webController.loadRequest(Uri.parse(finalUrl)).catchError((_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid URL')),
      );
    });
  }

  void _onGoPressed() {
    _lastUserInput = _urlController.text;
    _loadUrl(_urlController.text, fromUser: true);
  }

  Future<bool> _onSystemBack() async {
    if (_showHistory) {
      setState(() => _showHistory = false);
      return false;
    }
    if (await _webController.canGoBack()) {
      await _webController.goBack();
      return false;
    }
    return true;
  }

  Widget _buildHistoryDropdown() {
    if (!_showHistory || searchHistory.isEmpty) return const SizedBox.shrink();

    // show 4 max then scroll
    final visible = min(4, searchHistory.length);
    const tileH = 56.0;
    final height = 12 + 20 + 6 + (visible * tileH);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Text(
                  'History',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: searchHistory.length,
                  itemBuilder: (context, i) {
                    final value = searchHistory[i];
                    return SizedBox(
                      height: tileH,
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.history, size: 18),
                        title: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.north_west, size: 18),
                        onTap: () {
                          _urlController.text = value;
                          _lastUserInput = value;
                          _loadUrl(value, fromUser: false);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startDownload() async {
    String videoUrl = '';

    String? currentUrl;
    try {
      currentUrl = await _webController.currentUrl();
    } catch (_) {
      currentUrl = null;
    }

    if (currentUrl != null && _looksLikeMediaFile(currentUrl)) {
      videoUrl = currentUrl;
    }

    if (videoUrl.isEmpty) {
      const jsVideo = r"""
      (function() {
        try {
          var v = document.querySelector('video');
          if (!v) return '';
          if (v.currentSrc) return v.currentSrc;
          if (v.src) return v.src;
          var s = v.querySelector('source') || document.querySelector('video source');
          if (s && s.src) return s.src;
          return '';
        } catch(e) { return ''; }
      })();
      """;

      dynamic result;
      try {
        result = await _webController.runJavaScriptReturningResult(jsVideo);
      } catch (_) {
        result = null;
      }

      if (result is String) {
        videoUrl = result;
      } else if (result != null) {
        videoUrl = result.toString().replaceAll('"', '');
      }
    }

    if (videoUrl.isEmpty || !_looksLikeMediaFile(videoUrl)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No downloadable video found on this page.')),
      );
      return;
    }

    await downloadManager.startRealDownload(context: context, videoUrl: videoUrl);
  }

  Future<void> _goHome() async {
    setState(() => _showHistory = false);
    await _webController.loadRequest(Uri.parse('https://www.google.com/'));
  }

  Widget _topBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 22, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search or Type URL',
                        ),
                        textInputAction: TextInputAction.search,
                        onChanged: (v) => _lastUserInput = v,
                        onSubmitted: (_) => _onGoPressed(),
                        onTap: () => setState(() => _showHistory = true),
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _urlController.clear();
                        _lastUserInput = '';
                        setState(() => _showHistory = true);
                        _focusNode.requestFocus();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        height: 56,
        color: const Color(0xFF101117),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _canGoBack ? () => _webController.goBack() : null,
            ),
            IconButton(
              icon: const Icon(Icons.home_outlined),
              onPressed: _goHome,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _canGoForward ? () => _webController.goForward() : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return WillPopScope(
      onWillPop: _onSystemBack,
      child: Scaffold(
        backgroundColor: kBgColor,
        resizeToAvoidBottomInset: true,
        bottomNavigationBar: _bottomBar(),

        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              if (_showHistory) _buildHistoryDropdown(),

              Expanded(
                child: Stack(
                  children: [
                    // WebView always fills the remaining space
                    Positioned.fill(
                      child: WebViewWidget(controller: _webController),
                    ),

                    if (_focusNode.hasFocus || keyboardOpen)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _dismissInput,
                          onPanStart: (_) => _dismissInput(), // catches first scroll/drag
                          child: const SizedBox.expand(),
                        ),
                      ),

                    // Download floating button
                    Positioned(
                      right: 16,
                      bottom: 12,
                      child: ElevatedButton.icon(
                        onPressed: _startDownload,
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
