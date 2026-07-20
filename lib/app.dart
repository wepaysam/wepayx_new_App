import 'package:flutter/material.dart';

import 'ui/nex_app.dart';

/// Legacy entry — use [NexMaterialApp] from main.dart.
class NexWalletApp extends StatelessWidget {
  const NexWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const NexMaterialApp();
  }
}
