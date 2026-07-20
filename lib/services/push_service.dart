import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/api_models.dart';
import 'local_notification_service.dart';
import 'notification_delivery.dart';
import 'wallet_api.dart';

typedef PushNotificationHandler = void Function(PopupNotification notification);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final popup = PushService._toPopup(message);
  await LocalNotificationService.instance.initialize();
  await deliverPopupNotification(
    popup,
    showBanner: false,
    showLocalNotification: true,
    onBanner: (_) {},
  );
}

class PushService {
  PushService._();

  static final PushService instance = PushService._();

  final _messaging = FirebaseMessaging.instance;
  bool _ready = false;
  String? _token;
  PushNotificationHandler? onNotification;
  Future<void> Function(String token)? onTokenRefreshed;

  String? get token => _token;
  bool get isReady => _ready;

  Future<bool> initialize({PushNotificationHandler? onNotificationTap}) async {
    if (_ready) return true;
    onNotification = onNotificationTap;

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('PushService: notification permission denied');
      }

      _token = await _messaging.getToken().timeout(
        const Duration(seconds: 12),
        onTimeout: () => null,
      );
      debugPrint('PushService: FCM token $_token');

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        _handleOpenedMessage(initial);
      }

      _messaging.onTokenRefresh.listen((next) {
        _token = next;
        final handler = onTokenRefreshed;
        if (handler != null) {
          unawaited(handler(next));
        }
      });

      _ready = true;
      return true;
    } catch (e, st) {
      debugPrint('PushService init failed: $e\n$st');
      return false;
    }
  }

  Future<void> registerTokenWithApi(WalletApi api) async {
    final fcmToken = _token;
    if (fcmToken == null || fcmToken.isEmpty) return;
    try {
      await api.registerDeviceToken(token: fcmToken, platform: Platform.isIOS ? 'ios' : 'android');
    } catch (e) {
      debugPrint('PushService: register token failed: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final popup = _toPopup(message);
    await deliverPopupNotification(
      popup,
      showBanner: true,
      showLocalNotification: true,
      onBanner: (n) => onNotification?.call(n),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    onNotification?.call(_toPopup(message));
  }

  static PopupNotification _toPopup(RemoteMessage message) {
    final data = message.data;
    return PopupNotification(
      id: int.tryParse('${data['id'] ?? message.hashCode}') ?? message.hashCode,
      title: message.notification?.title ?? data['title']?.toString() ?? 'NEX Wallet',
      body: message.notification?.body ?? data['body']?.toString(),
      asset: data['asset']?.toString(),
      network: data['network']?.toString(),
      amount: data['amount']?.toString(),
      kind: data['kind']?.toString(),
    );
  }
}
