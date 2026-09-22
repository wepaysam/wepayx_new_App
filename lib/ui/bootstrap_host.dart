import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/wallet_provider.dart';
import '../services/app_update_service.dart';
import '../services/address_book_service.dart';
import '../services/local_notification_service.dart';
import '../services/notification_poller.dart';
import '../services/push_service.dart';
import '../services/security_service.dart';
import '../ui/widgets/nex_brand.dart';
import 'nex_app.dart';
import 'screens/nex_force_update_screen.dart';
import 'widgets/app_lock_screen.dart';

/// Boots services after the first frame so the APK never sits on a black native splash.
class NexBootstrapHost extends StatefulWidget {
  const NexBootstrapHost({super.key, required this.poller});

  final NotificationPoller poller;

  @override
  State<NexBootstrapHost> createState() => _NexBootstrapHostState();
}

class _NexBootstrapHostState extends State<NexBootstrapHost> {
  bool _ready = false;
  bool _forceUpdate = false;
  AppUpdateStatus? _updateStatus;
  String? _bootError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_boot()));
  }

  Future<AppUpdateStatus> _checkForRequiredUpdate() {
    return AppUpdateService.instance.checkForUpdate();
  }

  Future<void> _watchForRequiredUpdate() async {
    final AppUpdateStatus updateStatus;
    try {
      updateStatus = await _checkForRequiredUpdate();
    } catch (e) {
      debugPrint('AppUpdate: check failed: $e');
      return;
    }
    if (!mounted) return;

    debugPrint(
      'AppUpdate: local=${updateStatus.localLabel} '
      'remote=${updateStatus.remoteLabel} '
      'requires=${updateStatus.requiresUpdate} '
      'block=${updateStatus.mustBlockApp} '
      'error=${updateStatus.error}',
    );

    if (!updateStatus.mustBlockApp) return;
    setState(() {
      _forceUpdate = true;
      _updateStatus = updateStatus;
      _ready = true;
    });
  }

  Future<void> _boot({bool checkUpdate = true}) async {
    // The update gate runs alongside boot so the loading screen never waits on
    // the update server. Its verdict is applied as soon as it arrives.
    if (checkUpdate) unawaited(_watchForRequiredUpdate());

    final wallet = context.read<WalletProvider>();
    final security = SecurityService.instance;

    // Must settle before the first frame, otherwise the PIN lock would flash
    // the wallet before it can cover it.
    await _safe('security', security.init, const Duration(seconds: 8));

    await Future.wait([
      _safe(
        'addressBook',
        AddressBookService.instance.load,
        const Duration(seconds: 5),
      ),
      _safe('wallet', wallet.bootstrap, const Duration(seconds: 45)),
    ]);

    if (!mounted) return;
    setState(() => _ready = true);
    if (_forceUpdate) return;

    unawaited(_safe('notifications', () async {
      await LocalNotificationService.instance.initialize(
        onTap: wallet.showPushNotification,
      );
    }, const Duration(seconds: 15)));

    unawaited(_safe('push', () async {
      await PushService.instance.initialize(
        onNotificationTap: wallet.showPushNotification,
      );
      PushService.instance.onTokenRefreshed = (_) => wallet.registerPushToken();
      if (wallet.user != null) {
        await wallet.registerPushToken();
      }
    }, const Duration(seconds: 20)));

    unawaited(_safe('poller', widget.poller.start, const Duration(seconds: 10)));
  }

  Future<AppUpdateStatus> _recheckUpdate() async {
    final status = await _checkForRequiredUpdate();
    if (!mounted) return status;

    if (status.mustBlockApp) {
      setState(() => _updateStatus = status);
      return status;
    }

    setState(() {
      _forceUpdate = false;
      _updateStatus = null;
      _ready = false;
    });
    await _boot(checkUpdate: false);
    return status;
  }

  Future<void> _safe(
    String label,
    Future<void> Function() action,
    Duration timeout,
  ) async {
    try {
      await action().timeout(timeout);
    } catch (e, st) {
      debugPrint('NexBootstrap: $label failed: $e\n$st');
      if (label == 'wallet' && mounted) {
        setState(() => _bootError ??= 'Some services are slow or offline. You can still sign in.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // The mandatory-update gate outranks everything else, including boot state.
    if (_forceUpdate && _updateStatus != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF060D1A),
          colorScheme: const ColorScheme.dark(primary: Color(0xFF2DA8FF)),
        ),
        home: NexForceUpdateScreen(
          status: _updateStatus!,
          onRecheck: _recheckUpdate,
        ),
      );
    }

    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0A0A),
          colorScheme: const ColorScheme.dark(primary: Color(0xFF2DA8FF)),
        ),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const NexLogo(size: 56),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading NEX Wallet…',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_bootError != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _bootError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return AppLockGate(
      child: NexAppRootHost(poller: widget.poller),
    );
  }
}
