import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_update_service.dart';
import '../nex_tokens.dart';
import '../widgets/nex_brand.dart';
import '../widgets/nex_components.dart';
import 'nex_app_update_screen.dart';

const _appVersion = '1.0.0';
const _buildNumber = '1';

Future<String> _installedVersionLabel() async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version} (${info.buildNumber})';
}

void showNexComingSoon(BuildContext context, String feature) {
  showNexToast(context, '$feature — coming soon');
}

class NexAboutScreen extends StatelessWidget {
  const NexAboutScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) showNexToast(context, 'Could not open link');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);

    return Scaffold(
      backgroundColor: t.appBg,
      body: SafeArea(
        child: Column(
          children: [
            NexScreenHeader(title: 'About Us', onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F4FE0), Color(0xFF2DA8FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: nexBlue.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(child: NexLogo(size: 48, strokeWidth: 3)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'NEX Wallet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: t.text),
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<String>(
                    future: _installedVersionLabel(),
                    builder: (context, snapshot) => Text(
                      snapshot.data ?? 'v$_appVersion ($_buildNumber)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: t.muted),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Secure multi-asset wallet for send, receive, swap, and live markets.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: t.text2, height: 1.45),
                  ),
                  const SizedBox(height: 28),
                  NexSettingsGroup(
                    items: [
                      NexSettingsRow(
                        icon: 'shield',
                        label: 'User Agreement',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const NexTermsScreen()),
                        ),
                      ),
                      NexSettingsRow(
                        icon: 'lock',
                        label: 'Privacy Policy',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const NexPrivacyScreen()),
                        ),
                      ),
                      NexSettingsRow(
                        icon: 'clock',
                        label: 'Version History',
                        comingSoon: true,
                        onTap: () => showNexComingSoon(context, 'Version history'),
                      ),
                      NexSettingsRow(
                        icon: 'download',
                        label: 'Version Update',
                        onTap: () => openNexAppUpdateScreen(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  NexSettingsGroup(
                    items: [
                      NexSettingsRow(
                        icon: 'globe',
                        label: 'Website',
                        onTap: () => _openUrl(context, 'https://nexwallet.app'),
                      ),
                      NexSettingsRow(
                        icon: 'external',
                        label: 'Telegram',
                        comingSoon: true,
                        onTap: () => showNexComingSoon(context, 'Telegram community'),
                      ),
                      NexSettingsRow(
                        icon: 'external',
                        label: 'Twitter / X',
                        comingSoon: true,
                        onTap: () => showNexComingSoon(context, 'Social updates'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NexTermsScreen extends StatelessWidget {
  const NexTermsScreen({super.key});

  static const _sections = [
    (
      '1. Acceptance',
      'By creating a NEX Wallet account and using the app, you agree to these Terms. '
          'If you do not agree, do not use the service.',
    ),
    (
      '2. Wallet & custody',
      'NEX Wallet helps you view balances, receive deposits, request withdrawals, and swap assets through integrated providers. '
          'You are responsible for securing your device, PIN, and recovery information. '
          'Never share your PIN or approve transactions you do not understand.',
    ),
    (
      '3. Transactions',
      'Blockchain transfers are irreversible. Verify the asset, network, amount, and destination address before confirming send or swap actions. '
          'Network fees and processing times vary by chain.',
    ),
    (
      '4. Market data',
      'Prices shown in the app may come from third-party sources (e.g. CoinMarketCap or Coinbase) and are for information only — not financial advice.',
    ),
    (
      '5. Prohibited use',
      'You may not use NEX Wallet for illegal activity, fraud, money laundering, or to violate sanctions or applicable laws.',
    ),
    (
      '6. Service availability',
      'We may modify, suspend, or discontinue features at any time. Some features may be labelled “Coming soon” until they are released.',
    ),
    (
      '7. Limitation of liability',
      'To the fullest extent permitted by law, NEX Wallet is provided “as is” without warranties. '
          'We are not liable for losses caused by user error, network congestion, third-party providers, or unauthorized access to your device.',
    ),
    (
      '8. Contact',
      'For support questions about these Terms, contact your wallet operator or support channel listed in the app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    return Scaffold(
      backgroundColor: t.appBg,
      body: SafeArea(
        child: Column(
          children: [
            NexScreenHeader(
              title: 'User Agreement',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    'Last updated: June 2026',
                    style: TextStyle(fontSize: 13, color: t.muted),
                  ),
                  const SizedBox(height: 16),
                  ..._sections.map(
                    (section) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.$1,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: t.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            section.$2,
                            style: TextStyle(fontSize: 14, color: t.text2, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NexPrivacyScreen extends StatelessWidget {
  const NexPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    return Scaffold(
      backgroundColor: t.appBg,
      body: SafeArea(
        child: Column(
          children: [
            NexScreenHeader(
              title: 'Privacy Policy',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text('Last updated: June 2026', style: TextStyle(fontSize: 13, color: t.muted)),
                  const SizedBox(height: 16),
                  Text(
                    'NEX Wallet respects your privacy. This sample policy explains what we collect and how it is used.',
                    style: TextStyle(fontSize: 14, color: t.text2, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _privacyBlock(t, 'Information we collect', [
                    'Account email and profile name when you sign up.',
                    'Wallet activity required to provide balances, deposits, withdrawals, and notifications.',
                    'Device push token if you enable notifications.',
                    'App PIN is stored securely on your device — we do not store your PIN in plain text.',
                  ]),
                  _privacyBlock(t, 'How we use it', [
                    'To authenticate you and operate wallet features.',
                    'To send security and transaction alerts you opt into.',
                    'To improve reliability and prevent abuse.',
                  ]),
                  _privacyBlock(t, 'Third parties', [
                    'Blockchain networks process on-chain transactions.',
                    'Price providers (e.g. CoinMarketCap, Coinbase) supply market data.',
                    'Swap partners (e.g. SimpleSwap) process exchange quotes when you use swap.',
                  ]),
                  _privacyBlock(t, 'Your choices', [
                    'You can log out and remove local session data from the app.',
                    'You can disable biometrics and manage your PIN in Security settings.',
                    'You may request account support through your operator.',
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _privacyBlock(NexTokens t, String title, List<String> bullets) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.text)),
          const SizedBox(height: 8),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: t.muted, height: 1.45)),
                  Expanded(child: Text(b, style: TextStyle(fontSize: 14, color: t.text2, height: 1.45))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NexSettingsGroup extends StatelessWidget {
  const NexSettingsGroup({super.key, required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return NexCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              if (i > 0) const Divider(height: 1, thickness: 1),
              item,
            ],
          );
        }).toList(),
      ),
    );
  }
}

class NexSettingsRow extends StatelessWidget {
  const NexSettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.comingSoon = false,
    this.danger = false,
    this.trailing,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final bool comingSoon;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: t.cardSoft, shape: BoxShape.circle),
                child: Center(
                  child: NexIcon(
                    icon,
                    size: 18,
                    color: danger ? const Color(0xFFF87171) : t.text,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: danger ? const Color(0xFFF87171) : t.text,
                  ),
                ),
              ),
              if (comingSoon)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.cardSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Soon',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.muted),
                  ),
                )
              else if (trailing != null)
                trailing!
              else
                NexIcon('chevR', size: 18, color: t.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

class NexUpdateAppSettingsRow extends StatefulWidget {
  const NexUpdateAppSettingsRow({super.key});

  @override
  State<NexUpdateAppSettingsRow> createState() => _NexUpdateAppSettingsRowState();
}

class _NexUpdateAppSettingsRowState extends State<NexUpdateAppSettingsRow> {
  PackageInfo? _package;
  bool _hasUpdate = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final status = await AppUpdateService.instance.checkForUpdate();
    if (!mounted) return;
    setState(() {
      _package = status.package;
      _hasUpdate = status.hasUpdate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final version = _package == null ? '' : 'v${_package!.version}';

    return NexSettingsRow(
      icon: 'download',
      label: 'Update App',
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NexThemeScope(
              tokens: t,
              child: const NexAppUpdateScreen(),
            ),
          ),
        );
        await _load();
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasUpdate)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'New',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF22C55E)),
              ),
            ),
          if (version.isNotEmpty)
            Text(version, style: TextStyle(fontSize: 13, color: t.muted)),
          const SizedBox(width: 4),
          NexIcon('chevR', size: 18, color: t.subtle),
        ],
      ),
    );
  }
}
