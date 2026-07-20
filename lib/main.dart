import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/wallet_provider.dart';
import 'services/notification_poller.dart';
import 'services/push_service.dart';
import 'services/security_service.dart';
import 'ui/bootstrap_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final walletProvider = WalletProvider();
  final poller = NotificationPoller(walletProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: walletProvider),
        ChangeNotifierProvider.value(value: SecurityService.instance),
      ],
      child: NexBootstrapHost(poller: poller),
    ),
  );
}
