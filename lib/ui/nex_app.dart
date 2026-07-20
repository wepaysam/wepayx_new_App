import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/security_service.dart';
import '../services/notification_poller.dart';
import '../providers/wallet_provider.dart';
import 'nex_tokens.dart';
import 'nex_layout.dart';
import 'screens/nex_auth_screens.dart';
import 'screens/nex_flow_screens.dart';
import 'screens/nex_tab_screens.dart';
import 'widgets/nex_brand.dart';
import 'widgets/nex_components.dart';
import 'widgets/nex_pin_setup_screen.dart';

class NexRoute {
  const NexRoute(this.screen, [this.params = const {}]);
  final String screen;
  final Map<String, dynamic> params;
}

class NexAppRoot extends StatefulWidget {
  const NexAppRoot({super.key, this.poller});

  final NotificationPoller? poller;

  @override
  State<NexAppRoot> createState() => _NexAppRootState();
}

class _NexAppRootState extends State<NexAppRoot> with WidgetsBindingObserver {
  List<NexRoute> stack = [const NexRoute('landing')];
  String tab = 'home';

  NexRoute get current => stack.last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.poller?.pollOnResume() ?? Future.value());
    }
  }

  void navigate(String screen, [Map<String, dynamic> params = const {}]) {
    setState(() => stack = [...stack, NexRoute(screen, params)]);
  }

  void goBack() {
    if (stack.length <= 1) return;
    setState(() => stack = stack.sublist(0, stack.length - 1));
  }

  bool _canExitApp(WalletProvider provider) {
    if (stack.length > 1) return false;
    final screen = current.screen;
    if (screen == 'pin-setup') return false;
    if (screen == 'home' || screen == 'landing') return true;
    return false;
  }

  void _handleSystemBack(WalletProvider provider) {
    if (current.screen == 'pin-setup') return;
    if (stack.length > 1) {
      goBack();
      return;
    }

    const mainTabs = {'markets', 'wallet-tab', 'activity', 'profile'};
    if (mainTabs.contains(current.screen)) {
      setTab('home');
      return;
    }

    if (provider.user != null && current.screen != 'home' && current.screen != 'landing') {
      setTab('home');
    }
  }

  void setTab(String screen) {
    setState(() {
      tab = screen;
      stack = [NexRoute(screen)];
    });
  }

  void _goHomeOrPinSetup() {
    if (!SecurityService.instance.hasPin) {
      setState(() => stack = [const NexRoute('pin-setup')]);
      return;
    }
    setTab('home');
  }

  void replace(String screen, [Map<String, dynamic> params = const {}]) {
    setState(() => stack = [...stack.sublist(0, stack.length - 1), NexRoute(screen, params)]);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    if (!provider.initialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const NexLogo(size: 48),
              const SizedBox(height: 24),
              const CircularProgressIndicator(strokeWidth: 2.5),
            ],
          ),
        ),
      );
    }

    if (provider.user != null && stack.first.screen == 'landing') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goHomeOrPinSetup();
      });
    }

    if (provider.user != null &&
        !SecurityService.instance.hasPin &&
        current.screen != 'pin-setup' &&
        current.screen != 'login' &&
        current.screen != 'signup' &&
        current.screen != 'landing') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => stack = [const NexRoute('pin-setup')]);
      });
    }

    final tokens = provider.isDark ? NexTokens.darkTheme() : NexTokens.lightTheme();
    const tabs = {'home', 'markets', 'wallet-tab', 'activity', 'profile'};
    final showNav = tabs.contains(current.screen);
    final canExitApp = _canExitApp(provider);

    return PopScope(
      canPop: canExitApp,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack(provider);
      },
      child: NexThemeScope(
        tokens: tokens,
        child: Scaffold(
          backgroundColor: tokens.appBg,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(child: _buildScreen(provider)),
                    if (showNav)
                      NexBottomNav(
                        current: current.screen,
                        onSelect: setTab,
                      ),
                  ],
                ),
                if (provider.activePopup != null)
                  Positioned(
                    top: 8,
                    left: NexLayout.horizontalPadding(context),
                    right: NexLayout.horizontalPadding(context),
                    child: NexNotificationBanner(
                      title: provider.activePopup!.title,
                      body: provider.activePopup!.body ?? '',
                      onClose: provider.dismissPopup,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(WalletProvider provider) {
    switch (current.screen) {
      case 'landing':
        return NexLandingScreen(
          onSignup: () => navigate('signup'),
          onLogin: () => navigate('login'),
        );
      case 'signup':
        return NexSignupScreen(
          onBack: goBack,
          onSuccess: _goHomeOrPinSetup,
        );
      case 'login':
        return NexLoginScreen(
          onBack: goBack,
          onSuccess: _goHomeOrPinSetup,
        );
      case 'pin-setup':
        return NexPinSetupScreen(onComplete: () => setTab('home'));
      case 'home':
        return NexHomeScreen(
          onReceive: () => navigate('receive-asset'),
          onSend: () => navigate('send-asset'),
          onSwap: () => navigate('swap'),
          onBuy: () => navigate('buy'),
          onHistory: () => setTab('activity'),
          onProfile: () => setTab('profile'),
          onNotifications: () => navigate('notifications'),
          onAssetDetail: (id) => navigate('asset-detail', {'asset': id}),
        );
      case 'markets':
        return const NexMarketsScreen();
      case 'wallet-tab':
        return NexWalletTabScreen(
          onAssetDetail: (id) => navigate('asset-detail', {'asset': id}),
        );
      case 'activity':
        return const NexActivityScreen();
      case 'profile':
        return NexProfileScreen(
          onLogout: () async {
            await provider.logout();
            setState(() => stack = [const NexRoute('landing')]);
          },
          onActivity: () => setTab('activity'),
        );
      case 'receive-asset':
      case 'receive-network':
      case 'receive-qr':
        return NexReceiveFlow(onBack: goBack);
      case 'send-asset':
        return NexSendFlow(key: const ValueKey('nex-send-flow'), onBack: goBack);
      case 'swap':
        return NexSwapFlow(onBack: goBack);
      case 'buy':
      case 'notifications':
        return _PlaceholderFlow(title: current.screen, onBack: goBack);
      case 'asset-detail':
        return NexAssetDetailScreen(
          assetId: current.params['asset'] as String? ?? 'usdt',
          onBack: goBack,
        );
      default:
        return NexHomeScreen(
          onReceive: () => navigate('receive-asset'),
          onSend: () => navigate('send-asset'),
          onSwap: () => navigate('swap'),
          onBuy: () => navigate('buy'),
          onHistory: () => setTab('activity'),
          onProfile: () => setTab('profile'),
          onNotifications: () => navigate('notifications'),
          onAssetDetail: (id) => navigate('asset-detail', {'asset': id}),
        );
    }
  }
}

class _PlaceholderFlow extends StatelessWidget {
  const _PlaceholderFlow({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(title: title, onBack: onBack),
          Expanded(
            child: Center(
              child: Text('Coming soon', style: TextStyle(color: t.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

class NexMaterialApp extends StatelessWidget {
  const NexMaterialApp({super.key, this.poller});

  final NotificationPoller? poller;

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, _) {
        return MaterialApp(
          title: 'NEX Wallet',
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.1),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF4F7FF),
            textTheme: GoogleFonts.interTextTheme(),
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: Color(0xFF0F172A),
              contentTextStyle: TextStyle(color: Colors.white),
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0A0A0A),
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: Color(0xFF232325),
              contentTextStyle: TextStyle(color: Colors.white),
            ),
            useMaterial3: true,
          ),
          themeMode: provider.isDark ? ThemeMode.dark : ThemeMode.light,
          home: NexAppRoot(poller: poller),
        );
      },
    );
  }
}

/// Host for [NexMaterialApp] after bootstrap completes.
class NexAppRootHost extends StatelessWidget {
  const NexAppRootHost({super.key, required this.poller});

  final NotificationPoller poller;

  @override
  Widget build(BuildContext context) {
    return NexMaterialApp(poller: poller);
  }
}
