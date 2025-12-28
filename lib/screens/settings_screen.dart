import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants.dart';
import '../managers/download_manager.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();
  final SyncService _sync = SyncService();

  bool _busy = false;
  String? _busyAction; // which button is running (for per-button spinner)

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _runBusy(String action, Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyAction = action;
    });

    try {
      await task();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _busyAction = null;
      });
    }
  }

  Widget _settingsButton({
    required String label,
    required String actionKey,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null || _busy;
    final showSpinner = _busy && _busyAction == actionKey;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showSpinner)
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountTile({
    required bool loggedIn,
    required String email,
    required VoidCallback? onRightAction,
    required String rightLabel,
  }) {
    final disabled = onRightAction == null || _busy;
    final showSpinner = _busy && _busyAction == 'auth';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              loggedIn ? email : 'Login with Gmail',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: disabled ? null : onRightAction,
            child: Opacity(
              opacity: disabled ? 0.5 : 1,
              child: Row(
                children: [
                  Text(
                    rightLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (showSpinner) ...[
                    const SizedBox(width: 10),
                    const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _formatLastSync(DateTime? dt) {
    if (dt == null) return 'Last Sync: never';
    return 'Last Sync: ${DateFormat.yMd().add_jm().format(dt)}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, snap) {
        final user = snap.data;
        final loggedIn = user != null;
        final email = user?.email ?? '';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            backgroundColor: kBgColor,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Account row: email + Logout/Login on right
                _accountTile(
                  loggedIn: loggedIn,
                  email: email,
                  rightLabel: loggedIn ? 'Logout' : 'Login',
                  onRightAction: () => _runBusy('auth', () async {
                    if (loggedIn) {
                      await _auth.signOut();
                      _snack('Logged out');
                    } else {
                      final cred = await _auth.signInWithGoogle();
                      if (cred == null) return; // cancelled
                      _snack('Logged in as ${cred.user?.email ?? ''}');
                    }
                  }),
                ),

                _settingsButton(
                  label: 'Sync Now',
                  actionKey: 'sync',
                  onTap: !loggedIn
                      ? null
                      : () => _runBusy('sync', () async {
                    await _sync.syncAll(user.uid);
                    _snack('Sync completed');
                  }),
                ),

                _settingsButton(
                  label: 'Retrieve Data',
                  actionKey: 'retrieve',
                  onTap: !loggedIn
                      ? null
                      : () => _runBusy('retrieve', () async {
                    await _sync.retrieveAll(user.uid);

                    // ✅ refresh UI after pulling data into Hive
                    await downloadManager.loadFromHive();
                    await downloadManager.loadStudioFromHive();
                    _snack('Data retrieved');
                  }),
                ),

                // ✅ Delete Firebase Data (cloud wipe)
                _settingsButton(
                  label: 'Delete Firebase Data',
                  actionKey: 'deleteCloud',
                  onTap: !loggedIn
                      ? null
                      : () => _runBusy('deleteCloud', () async {
                    final ok = await _confirmDialog(
                      title: 'Delete cloud backup?',
                      message:
                      'This will delete your synced folders, items, and web history from Firebase for this account.',
                      confirmText: 'Delete',
                    );
                    if (!ok) return;

                    await _sync.deleteCloudData(user.uid);
                    _snack('Cloud data deleted');
                  }),
                ),

                const SizedBox(height: 24),

                if (!loggedIn)
                  const Text(
                    'Last Sync: —',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  )
                else
                  StreamBuilder<DateTime?>(
                    stream: _sync.lastSyncStream(user.uid),
                    builder: (context, lastSnap) {
                      return Text(
                        _formatLastSync(lastSnap.data),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
