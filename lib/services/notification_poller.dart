import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../config/api_config.dart';
import '../providers/wallet_provider.dart';
import 'api_client.dart';
import 'local_notification_service.dart';
import 'notification_delivery.dart';
import 'wallet_api.dart';

const notificationPollTaskName = 'nexWalletNotificationPoll';

@pragma('vm:entry-point')
void notificationPollCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await _pollInBackground();
      return true;
    } catch (e) {
      debugPrint('Background notification poll failed: $e');
      return false;
    }
  });
}

Future<void> _pollInBackground() async {
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('api_base_url');
  if (savedUrl != null && savedUrl.isNotEmpty) {
    ApiConfig.setBaseUrl(savedUrl);
  }
  final savedKey = prefs.getString('futre_api_key');
  if (savedKey != null && savedKey.isNotEmpty) {
    ApiConfig.setApiKey(savedKey);
  }

  await ApiClient.instance.init();
  await LocalNotificationService.instance.initialize();

  final session = await WalletApi(ApiClient.instance).me();
  if (session.user == null) return;

  final notifications = await WalletApi(
    ApiClient.instance,
  ).popupNotifications();
  if (notifications.isEmpty) return;

  for (final item in notifications) {
    await deliverPopupNotification(
      item,
      showBanner: false,
      showLocalNotification: true,
      onBanner: (_) {},
    );
  }
}

class NotificationPoller {
  NotificationPoller(this._provider);

  final WalletProvider _provider;
  Timer? _foregroundTimer;
  Timer? _priceTimer;
  Timer? _walletTimer;
  bool _running = false;
  bool _pollInFlight = false;

  /// Notifications are cheap (one endpoint), so they poll fast.
  static const _notificationInterval = Duration(seconds: 2);

  /// Balances hit several wallet endpoints, so they refresh on a slower beat.
  static const _walletInterval = Duration(seconds: 20);

  Future<void> start() async {
    _startForegroundPolling();
    _startWalletPolling();
    _startPricePolling();
    unawaited(registerBackgroundPolling());
  }

  void stop() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    _priceTimer?.cancel();
    _priceTimer = null;
    _walletTimer?.cancel();
    _walletTimer = null;
    _running = false;
  }

  Future<void> registerBackgroundPolling() async {
    try {
      await Workmanager().initialize(notificationPollCallbackDispatcher);
      await Workmanager().registerPeriodicTask(
        notificationPollTaskName,
        notificationPollTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
      debugPrint(
        'NotificationPoller: background task registered (every ~15 min)',
      );
    } catch (e) {
      debugPrint('NotificationPoller: background task setup failed: $e');
    }
  }

  void _startForegroundPolling() {
    if (_running) return;
    _running = true;
    unawaited(_pollOnce());
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer.periodic(
      _notificationInterval,
      (_) => _pollOnce(),
    );
  }

  void _startWalletPolling() {
    unawaited(_refreshWalletOnce());
    _walletTimer?.cancel();
    _walletTimer = Timer.periodic(
      _walletInterval,
      (_) => _refreshWalletOnce(),
    );
  }

  Future<void> pollOnResume() async {
    await Future.wait([
      _pollOnce(),
      _refreshWalletOnce(),
      _provider.refreshPrices(),
      _provider.refreshAccountFeatures(),
    ]);
  }

  Future<void> _refreshWalletOnce() async {
    if (_provider.user == null) return;
    try {
      await _provider.refreshWallet();
    } catch (e) {
      debugPrint('NotificationPoller: wallet refresh failed: $e');
    }
  }

  void _startPricePolling() {
    unawaited(_provider.refreshPrices());
    _priceTimer?.cancel();
    _priceTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(_provider.refreshPrices());
    });
  }

  Future<void> _pollOnce() async {
    if (_provider.user == null || _pollInFlight) return;
    _pollInFlight = true;
    try {
      await _provider.pollNotifications(
        showBanner: true,
        showLocalNotification: true,
      );
    } catch (e) {
      debugPrint('NotificationPoller: foreground poll failed: $e');
    } finally {
      _pollInFlight = false;
    }
  }
}
