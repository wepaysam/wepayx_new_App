import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/wallet_provider.dart';
import '../screens/activity/activity_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/markets/markets_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/wallet/wallet_tab_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    Future<void> poll() async {
      if (!mounted) return;
      final provider = context.read<WalletProvider>();
      await provider.refreshWallet();
      await provider.pollNotifications();
      await Future<void>.delayed(const Duration(seconds: 4));
      if (mounted) poll();
    }

    Future<void>.delayed(const Duration(seconds: 2), poll);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final pages = [
      const HomeScreen(),
      const MarketsScreen(),
      const WalletTabScreen(),
      const ActivityScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: index, children: pages),
          if (provider.activePopup != null)
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.paddingOf(context).top + 8,
              child: _PopupBanner(
                notification: provider.activePopup!,
                onClose: provider.dismissPopup,
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'Markets'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _PopupBanner extends StatelessWidget {
  const _PopupBanner({
    required this.notification,
    required this.onClose,
  });

  final dynamic notification;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).cardTheme.color,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (notification.body != null) ...[
                    const SizedBox(height: 4),
                    Text(notification.body!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 18)),
          ],
        ),
      ),
    );
  }
}
