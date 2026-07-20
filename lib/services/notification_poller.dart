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

  final notifications = await WalletApi(ApiClient.instance).popupNotifications();
  if (notifications.isEmpty) return;

  final latest = notifications.last;
  await deliverPopupNotification(
    latest,
    showBanner: false,
    showLocalNotification: true,
    onBanner: (_) {},
  );
}

class NotificationPoller {
  NotificationPoller(this._provider);

  final WalletProvider _provider;
  Timer? _foregroundTimer;
  Timer? _priceTimer;
  bool _running = false;

  Future<void> start() async {
    await registerBackgroundPolling();
    _startForegroundPolling();
    _startPricePolling();
  }

  void stop() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    _priceTimer?.cancel();
    _priceTimer = null;
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
      debugPrint('NotificationPoller: background task registered (every ~15 min)');
    } catch (e) {
      debugPrint('NotificationPoller: background task setup failed: $e');
    }
  }

  void _startForegroundPolling() {
    if (_running) return;
    _running = true;
    unawaited(_pollOnce());
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollOnce());
  }

  Future<void> pollOnResume() async {
    await Future.wait([
      _pollOnce(),
      _provider.refreshPrices(),
    ]);
  }

  void _startPricePolling() {
    unawaited(_provider.refreshPrices());
    _priceTimer?.cancel();
    _priceTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(_provider.refreshPrices());
    });
  }

  Future<void> _pollOnce() async {
    if (_provider.user == null) return;
    try {
      await _provider.refreshWallet();
      await _provider.pollNotifications(
        showBanner: true,
        showLocalNotification: true,
      );
    } catch (e) {
      debugPrint('NotificationPoller: foreground poll failed: $e');
    }
  }
}
