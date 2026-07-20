import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/api_models.dart';

const nexNotificationChannelId = 'nex_wallet_alerts';
const nexNotificationChannelName = 'NEX Wallet Alerts';

typedef NotificationTapHandler = void Function(PopupNotification notification);

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  NotificationTapHandler? onTap;

  bool get isReady => _ready;

  Future<void> initialize({NotificationTapHandler? onTap}) async {
    if (_ready) return;
    this.onTap = onTap;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        onTap?.call(PopupNotification(id: response.id ?? 0, title: payload));
      },
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              nexNotificationChannelId,
              nexNotificationChannelName,
              description: 'Deposits, withdrawals, and wallet alerts',
              importance: Importance.high,
            ),
          );
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _ready = true;
    debugPrint('LocalNotificationService: ready');
  }

  Future<void> show(PopupNotification notification) async {
    if (!_ready) await initialize();
    final body = notification.body ?? '';
    final id = notification.id == 0 ? notification.hashCode : notification.id;

    await _plugin.show(
      id,
      notification.title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          nexNotificationChannelId,
          nexNotificationChannelName,
          channelDescription: 'Deposits, withdrawals, and wallet alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: body.length > 48
              ? BigTextStyleInformation(body, contentTitle: notification.title)
              : null,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: notification.title,
    );
  }
}
