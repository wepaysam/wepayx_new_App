import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_models.dart';
import 'local_notification_service.dart';

const lastNotificationIdKey = 'last_popup_notification_id';

Future<bool> markNotificationIfNew(int id) async {
  if (id <= 0) return true;
  final prefs = await SharedPreferences.getInstance();
  final last = prefs.getInt(lastNotificationIdKey) ?? 0;
  if (id <= last) return false;
  await prefs.setInt(lastNotificationIdKey, id);
  return true;
}

Future<void> clearLastNotificationId() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(lastNotificationIdKey);
}

Future<bool> deliverPopupNotification(
  PopupNotification notification, {
  required bool showBanner,
  required bool showLocalNotification,
  required void Function(PopupNotification) onBanner,
}) async {
  if (!await markNotificationIfNew(notification.id)) return false;

  if (showLocalNotification) {
    await LocalNotificationService.instance.show(notification);
  }
  if (showBanner) {
    onBanner(notification);
  }
  return true;
}
