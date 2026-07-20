import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/assets.dart';
import '../../core/utils/address_utils.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/tx_utils.dart';
import '../../models/api_models.dart';
import '../../models/wallet_model.dart';
import '../../services/deposit_card_service.dart';
import '../../providers/wallet_provider.dart';
import '../nex_layout.dart';
import '../nex_tokens.dart';
import '../widgets/nex_brand.dart';
import '../widgets/address_qr_scanner_screen.dart';
import '../widgets/app_lock_screen.dart';
import '../widgets/nex_components.dart';
import '../widgets/nex_security_settings.dart';
import 'nex_settings_screens.dart';

class NexProfileScreen extends StatelessWidget {
  const NexProfileScreen({
    super.key,
    required this.onLogout,
    this.onActivity,
  });

  final VoidCallback onLogout;
  final VoidCallback? onActivity;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final provider = context.watch<WalletProvider>();
    final user = provider.user;
    final initial = (user?.name ?? user?.email ?? 'W').substring(0, 1).toUpperCase();

    Widget sectionLabel(String title) {
      return Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
        child: NexLabel(title),
      );
    }

    void openSecurity() {
      final parentContext = context;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => NexThemeScope(
          tokens: t,
          child: NexSecuritySettingsSheet(
            onPasswordChanged: () async {
              Navigator.of(sheetContext).pop();
              await parentContext.read<WalletProvider>().logout();
              if (!parentContext.mounted) return;
              showNexToast(
                parentContext,
                'Password updated. Please sign in again.',
              );
              onLogout();
            },
          ),
        ),
      );
    }

    return ColoredBox(
      color: t.appBg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const NexScreenHeader(title: 'My Wallet'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: NexCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F4FE0), Color(0xFF2DA8FF)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Wallet User',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: t.text),
                        ),
                        Text(
                          user?.email ?? 'Login required',
                          style: TextStyle(fontSize: 13, color: t.text2),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ID: ${user != null ? 'futre-${user.id}' : 'not linked'}',
                          style: TextStyle(fontSize: 11, color: t.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionLabel('Wallet'),
                NexSettingsGroup(
                  items: [
                    NexSettingsRow(
                      icon: 'clock',
                      label: 'Transaction History',
                      onTap: onActivity,
                    ),
                    NexSettingsRow(
                      icon: 'user',
                      label: 'Address Book',
                      comingSoon: true,
                      onTap: () => showNexComingSoon(context, 'Address book'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                sectionLabel('Preferences'),
                NexSettingsGroup(
                  items: [
                    NexSettingsRow(
                      icon: 'shield',
                      label: 'Security & Privacy',
                      onTap: openSecurity,
                    ),
                    NexSettingsRow(
                      icon: provider.isDark ? 'moon' : 'sun',
                      label: provider.isDark ? 'Dark mode' : 'Light mode',
                      trailing: Switch.adaptive(
                        value: provider.isDark,
                        onChanged: (_) => provider.toggleTheme(),
                      ),
                    ),
                    const NexUpdateAppSettingsRow(),
                  ],
                ),
                const SizedBox(height: 20),
                sectionLabel('Support'),
                NexSettingsGroup(
                  items: [
                    NexSettingsRow(
                      icon: 'help',
                      label: 'Help & Support',
                      onTap: () => showNexComingSoon(context, 'Help center'),
                    ),
                    NexSettingsRow(
                      icon: 'info',
                      label: 'Wallet Guide',
                      comingSoon: true,
                      onTap: () => showNexComingSoon(context, 'Wallet guide'),
                    ),
                    NexSettingsRow(
                      icon: 'bell',
                      label: 'Announcements',
                      comingSoon: true,
                      onTap: () => showNexComingSoon(context, 'Announcements'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                sectionLabel('About'),
                NexSettingsGroup(
                  items: [
                    NexSettingsRow(
                      icon: 'globe',
                      label: 'About Us',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const NexAboutScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                sectionLabel('Account'),
                NexSettingsGroup(
                  items: [
                    NexSettingsRow(
                      icon: 'logout',
                      label: 'Log out',
                      danger: true,
                      onTap: onLogout,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NexReceiveFlow extends StatefulWidget {
  const NexReceiveFlow({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<NexReceiveFlow> createState() => _NexReceiveFlowState();
}

class _NexReceiveFlowState extends State<NexReceiveFlow> {
  AssetDefinition? asset;
  String? network;
  DepositAddressResult? result;
  bool loading = false;
  bool _sharing = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WalletProvider>().fetchFees();
    });
  }

  Future<void> _pickNetwork(String n) async {
    setState(() {
      network = n;
      loading = true;
    });
    try {
      final data = await context.read<WalletProvider>().depositAddress(
            asset: asset!.symbol,
            network: n,
          );
      setState(() => result = data);
    } catch (e) {
      if (mounted) showNexToast(context, e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _handleSystemBack() {
    if (network != null) {
      setState(() => network = null);
    } else if (asset != null) {
      setState(() => asset = null);
    } else {
      widget.onBack();
    }
  }

  Future<void> _shareDeposit(String addr, String symbol, String net) async {
    if (addr.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      await DepositCardService.instance.share(
        address: addr,
        symbol: symbol,
        network: net,
      );
    } catch (e) {
      if (mounted) showNexToast(context, 'Share failed: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _downloadDepositQr(String addr, String symbol, String net) async {
    if (addr.isEmpty || _downloading) return;
    setState(() => _downloading = true);
    try {
      await DepositCardService.instance.download(
        address: addr,
        symbol: symbol,
        network: net,
      );
      if (mounted) showNexToast(context, 'QR saved to gallery');
    } catch (e) {
      if (mounted) showNexToast(context, 'Download failed: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Widget _depositActionButton({
    required NexTokens t,
    required String icon,
    required String label,
    required VoidCallback? onTap,
    bool outlined = false,
    bool busy = false,
  }) {
    final fg = outlined ? t.text : t.pillActiveText;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else
          NexIcon(icon, size: 18, color: fg),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: fg),
          ),
        ),
      ],
    );

    if (outlined) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: t.text,
          backgroundColor: t.cardSoft,
          side: BorderSide(color: t.inputBorder),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: t.pillActiveBg,
        foregroundColor: t.pillActiveText,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget screen;
    if (asset == null) {
      screen = _assetPicker(context, (a) => setState(() => asset = a));
    } else if (network == null) {
      screen = _networkPicker(context, asset!, _pickNetwork);
    } else {
      screen = _depositQr(context);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack();
      },
      child: screen,
    );
  }

  Widget _assetPicker(BuildContext context, ValueChanged<AssetDefinition> onPick) {
    return ColoredBox(
      color: NexThemeScope.of(context).appBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NexScreenHeader(title: 'Receive', onBack: widget.onBack),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: NexLayout.horizontalPadding(context)),
              children: kSupportedAssets
                  .where((a) => a.symbol != 'TRX')
                  .map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: NexCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => onPick(a),
                        child: Row(
                          children: [
                            CoinLogo(symbol: a.symbol, color: a.color, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.name, style: TextStyle(fontWeight: FontWeight.w600, color: NexThemeScope.of(context).text)),
                                  Text(a.symbol, style: TextStyle(color: NexThemeScope.of(context).muted)),
                                ],
                              ),
                            ),
                            NexIcon('chevR', size: 18, color: NexThemeScope.of(context).subtle),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _networkPicker(
    BuildContext context,
    AssetDefinition asset,
    ValueChanged<String> onPick,
  ) {
    final provider = context.watch<WalletProvider>();
    return ColoredBox(
      color: NexThemeScope.of(context).appBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NexScreenHeader(title: 'Receive ${asset.symbol}', onBack: () => setState(() => this.asset = null)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: asset.networks.map((n) {
                final feeLine = provider.feeLineFor(asset.symbol, n);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NexCard(
                    padding: const EdgeInsets.all(14),
                    onTap: () => onPick(n),
                    child: Row(
                      children: [
                        NetworkIcon(network: n, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(networkLabel(n), style: const TextStyle(fontWeight: FontWeight.w700)),
                              if (feeLine.isNotEmpty) Text(feeLine, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        NexIcon('chevR', size: 18, color: NexThemeScope.of(context).subtle),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _depositQr(BuildContext context) {
    final t = NexThemeScope.of(context);
    final provider = context.watch<WalletProvider>();
    final a = asset!;
    final n = network!;
    final feeLabel = provider.feeDisplayFor(a.symbol, n);
    final addr = result?.depositAddress ?? '';
    final hPad = NexLayout.horizontalPadding(context);
    final qrSize = NexLayout.qrSize(context);

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(
            title: 'Receive ${a.symbol}',
            onBack: () => setState(() => network = null),
          ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
                children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const NexLogo(size: 22),
                              const SizedBox(width: 7),
                              Text('NEX Wallet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: t.text)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text('Deposit ${a.symbol}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: t.text)),
                          Text(
                            'Scan the QR code or copy the wallet address',
                            style: TextStyle(fontSize: 12, color: t.text2),
                          ),
                        ],
                      ),
                    ),
                    CoinLogo(symbol: a.symbol, color: a.color, size: 40),
                  ],
                ),
                const SizedBox(height: 16),
                if (loading)
                  Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: t.navActive)))
                else
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: t.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.cardBorder),
                      boxShadow: t.dark
                          ? null
                          : const [BoxShadow(color: Color(0x1F0F172A), blurRadius: 24, offset: Offset(0, 10))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Network', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.muted)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: t.inputBorder),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            children: [
                              NetworkIcon(network: n, size: 26),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  networkLabel(n),
                                  style: TextStyle(fontWeight: FontWeight.w700, color: t.text),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5).withValues(alpha: t.dark ? 0.2 : 1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text('Active', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: QrImageView(data: addr, size: qrSize, backgroundColor: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Deposit address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.muted)),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: t.inputBorder),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    addr,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: t.text),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: addr));
                                  showNexToast(context, 'Address copied');
                                },
                                child: Container(
                                  width: 38,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    border: Border(left: BorderSide(color: t.inputBorder)),
                                  ),
                                  child: Center(child: NexIcon('copy', size: 18, color: t.muted)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: addr.isEmpty || _downloading
                                ? null
                                : () => _downloadDepositQr(addr, a.symbol, n),
                            icon: _downloading
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: t.text),
                                  )
                                : NexIcon('download', size: 16, color: t.text),
                            label: Text(
                              _downloading ? 'Downloading…' : 'Download QR',
                              style: TextStyle(fontWeight: FontWeight.w800, color: t.text),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: t.cardSoft,
                              foregroundColor: t.text,
                              side: BorderSide(color: t.inputBorder),
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                            ),
                          ),
                        ),
                        if (feeLabel != '—') ...[
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: t.inputBorder),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Network fee', style: TextStyle(fontSize: 11, color: t.muted, fontWeight: FontWeight.w600)),
                                        Text(feeLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 48, color: t.inputBorder),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Important', style: TextStyle(fontSize: 11, color: t.muted, fontWeight: FontWeight.w600)),
                                        Text(
                                          'Send only on selected network',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.text),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: ['Secure', 'Fast', 'Simple'].map((label) {
                    return Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: t.inputBorder),
                            ),
                            child: Center(child: NexIcon(label == 'Fast' ? 'refresh' : 'shield', size: 18, color: t.muted)),
                          ),
                          const SizedBox(height: 8),
                          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.text2)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _depositActionButton(
                        t: t,
                        icon: 'copy',
                        label: 'Copy',
                        onTap: addr.isEmpty
                            ? null
                            : () {
                                Clipboard.setData(ClipboardData(text: addr));
                                showNexToast(context, 'Address copied');
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _depositActionButton(
                        t: t,
                        icon: 'external',
                        label: 'Share',
                        outlined: true,
                        busy: _sharing,
                        onTap: addr.isEmpty || _sharing
                            ? null
                            : () => unawaited(_shareDeposit(addr, a.symbol, n)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _SendStep { asset, network, form, review, processing, success }

class NexSendFlow extends StatefulWidget {
  const NexSendFlow({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<NexSendFlow> createState() => _NexSendFlowState();
}

class _NexSendFlowState extends State<NexSendFlow> {
  _SendStep step = _SendStep.asset;
  AssetDefinition? asset;
  String? network;
  final _address = TextEditingController();
  final _amount = TextEditingController();
  WithdrawalResult? result;
  bool submitting = false;
  String? submitError;
  DateTime? _submittedAt;
  Timer? _withdrawalStatusPoll;

  bool _withdrawalIsFullyComplete(String? status, String? txid) {
    if (txIsPending(status)) return false;
    final value = (status ?? '').toLowerCase();
    if (['failed', 'refunded', 'withdrawal_failed'].contains(value)) return true;
    if (['completed', 'confirmed', 'success', 'sent'].contains(value)) {
      return txid != null && txid.isNotEmpty;
    }
    return false;
  }

  bool _withdrawalInProgress(String? status, String? txid) => !_withdrawalIsFullyComplete(status, txid);

  String? _txidFromActivity(WalletProvider provider, int withdrawalId) {
    if (withdrawalId <= 0) return null;
    final key = 'futre-withdrawal-$withdrawalId';
    for (final item in provider.wallet.activity) {
      if (item.id == key || item.reference?.contains('$withdrawalId') == true) {
        final tx = item.txid;
        if (tx != null && tx.isNotEmpty && !tx.startsWith('futre-withdrawal-')) {
          return tx;
        }
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WalletProvider>().fetchFees();
    });
  }

  @override
  void dispose() {
    _withdrawalStatusPoll?.cancel();
    _address.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _stopStatusPoll() {
    _withdrawalStatusPoll?.cancel();
    _withdrawalStatusPoll = null;
  }

  void _startStatusPoll() {
    _stopStatusPoll();
    _withdrawalStatusPoll = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_pollWithdrawalStatus());
    });
  }

  Future<void> _pollWithdrawalStatus() async {
    if (!mounted || step != _SendStep.success || asset == null || network == null) return;
    final provider = context.read<WalletProvider>();
    await provider.refreshWallet();
    if (!mounted) return;

    final pending = provider.pendingWithdrawal;
    if (pending != null &&
        pending.asset == asset!.symbol &&
        pending.network == network) {
      final txid = result?.txid ?? _txidFromActivity(provider, pending.id);
      setState(() {
        result = WithdrawalResult(
          id: pending.id,
          status: pending.status,
          asset: pending.asset,
          network: pending.network,
          amount: pending.amount,
          fee: result?.fee,
          netAmount: result?.netAmount,
          txid: txid,
        );
      });
      if (!_withdrawalInProgress(pending.status, txid)) {
        _stopStatusPoll();
        setState(() => submitting = false);
      }
      return;
    }

    if (result != null) {
      final txid = result!.txid ?? _txidFromActivity(provider, result!.id);
      if (txid != result!.txid) {
        setState(() {
          result = WithdrawalResult(
            id: result!.id,
            status: result!.status,
            asset: result!.asset,
            network: result!.network,
            amount: result!.amount,
            fee: result!.fee,
            netAmount: result!.netAmount,
            txid: txid,
          );
        });
      }
      if (!_withdrawalInProgress(result!.status, txid)) {
        _stopStatusPoll();
        if (mounted) setState(() => submitting = false);
      }
    }
  }

  void _back() {
    switch (step) {
      case _SendStep.asset:
        widget.onBack();
      case _SendStep.network:
        setState(() {
          step = _SendStep.asset;
          asset = null;
        });
      case _SendStep.form:
        setState(() {
          step = _SendStep.network;
          network = null;
          _address.clear();
          _amount.clear();
        });
      case _SendStep.review:
        setState(() => step = _SendStep.form);
      case _SendStep.processing:
      case _SendStep.success:
        widget.onBack();
    }
  }

  double _balance(WalletProvider provider) {
    if (asset == null) return 0;
    return provider.assetViews
        .firstWhere((v) => v.definition.id == asset!.id, orElse: () => provider.assetViews.first)
        .amount;
  }

  double _networkBalance(WalletProvider provider) {
    if (asset == null || network == null) return 0;
    return _balanceForNetwork(provider, network!);
  }

  double _balanceForNetwork(WalletProvider provider, String net) {
    if (asset == null) return 0;
    final rows = rowsForNetwork(provider, net);
    if (rows.isNotEmpty) {
      return rows.fold(0.0, (sum, row) => sum + row.balance);
    }
    if (asset!.networks.length == 1 && asset!.networks.first == net) {
      return _balance(provider);
    }
    return 0;
  }

  List<BalanceRow> rowsForNetwork(WalletProvider provider, [String? net]) {
    final selected = net ?? network;
    if (asset == null || selected == null) return const [];
    return provider.wallet.balances
        .where((row) => row.asset == asset!.symbol && row.network == selected)
        .toList();
  }

  String _balanceLabel(WalletProvider provider, double amount, String symbol) {
    if (!provider.balanceVisible) return '••••';
    return '${Formatters.amount(amount)} $symbol';
  }

  void _applyRecipientAddress(String raw) {
    final n = network;
    if (n == null) return;
    final parsed = parseWalletAddress(raw, network: n);
    if (parsed == null) {
      showNexToast(context, 'Could not read a valid $n address');
      return;
    }
    _address.text = parsed;
    setState(() {});
  }

  Future<void> _pasteRecipientAddress() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) showNexToast(context, 'Clipboard is empty');
      return;
    }
    _applyRecipientAddress(text);
  }

  Future<void> _scanRecipientAddress() async {
    final n = network;
    if (n == null) return;
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => NexThemeScope(
          tokens: NexThemeScope.of(context),
          child: AddressQrScannerScreen(network: n),
        ),
      ),
    );
    if (scanned != null && scanned.isNotEmpty) {
      _applyRecipientAddress(scanned);
    }
  }

  double _price(WalletProvider provider) {
    if (asset == null) return 0;
    return provider.assetViews
        .firstWhere((v) => v.definition.id == asset!.id, orElse: () => provider.assetViews.first)
        .price;
  }

  double _receiverGets(WalletProvider provider, String symbol) {
    if (network == null) return _amountNum;
    return provider.receiverGetsAmount(
      symbol: symbol,
      network: network!,
      amount: _amountNum,
    );
  }

  double get _amountNum => double.tryParse(_amount.text.trim()) ?? 0;

  Future<void> _submit() async {
    if (asset == null || network == null || submitting) return;

    final authed = await authenticateSensitiveAction(
      context,
      reason: 'Confirm sending ${Formatters.amount(_amountNum)} ${asset!.symbol}',
    );
    if (!authed || !mounted) return;

    setState(() {
      submitting = true;
      submitError = null;
      _submittedAt = DateTime.now();
      step = _SendStep.success;
      result = null;
    });
    _startStatusPoll();
    try {
      final data = await context.read<WalletProvider>().withdraw(
            asset: asset!.symbol,
            network: network!,
            amount: _amount.text.trim(),
            toAddress: _address.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        result = data;
        step = _SendStep.success;
        submitting = _withdrawalInProgress(data.status, data.txid);
      });
      if (!_withdrawalInProgress(data.status, data.txid)) {
        _stopStatusPoll();
      }
    } catch (e) {
      if (!mounted) return;
      final provider = context.read<WalletProvider>();
      await provider.refreshWallet();
      if (!mounted) return;

      final pending = provider.pendingWithdrawal;
      final timedOut = e.toString().toLowerCase().contains('longer than expected') ||
          e.toString().toLowerCase().contains('timeout') ||
          e.toString().contains('0:00:30');

      if (timedOut &&
          pending != null &&
          pending.asset == asset!.symbol &&
          pending.network == network) {
        setState(() {
          result = WithdrawalResult(
            id: pending.id,
            status: pending.status,
            asset: pending.asset,
            network: pending.network,
            amount: pending.amount,
          );
          step = _SendStep.success;
          submitting = _withdrawalInProgress(pending.status, result?.txid);
          submitError = null;
        });
        if (!_withdrawalInProgress(pending.status, result?.txid)) {
          _stopStatusPoll();
        }
        return;
      }

      final message = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      _stopStatusPoll();
      setState(() {
        step = _SendStep.review;
        submitting = false;
        submitError = message;
      });
      if (mounted) showNexError(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = switch (step) {
      _SendStep.asset => _assetPicker(context, context.watch<WalletProvider>()),
      _SendStep.network => _networkPicker(context, context.watch<WalletProvider>()),
      _SendStep.form => _sendForm(context, context.watch<WalletProvider>()),
      _SendStep.review => _sendReview(context, context.watch<WalletProvider>()),
      _SendStep.processing => _withdrawalProgress(context),
      _SendStep.success => _withdrawalProgress(context),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: screen,
    );
  }

  Widget _assetPicker(BuildContext context, WalletProvider provider) {
    final t = NexThemeScope.of(context);
    return ColoredBox(
      color: t.appBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NexScreenHeader(title: 'Send', onBack: widget.onBack),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Choose an asset to send.', style: TextStyle(fontSize: 15, color: t.text2)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: provider.assetViews.map((view) {
                final a = view.definition;
                final disabled = a.symbol == 'TRX';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NexCard(
                    padding: const EdgeInsets.all(14),
                    onTap: disabled
                        ? null
                        : () => setState(() {
                              asset = a;
                              step = _SendStep.network;
                            }),
                    child: Opacity(
                      opacity: disabled ? 0.45 : 1,
                      child: Row(
                        children: [
                          CoinLogo(symbol: a.symbol, color: a.color, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.name, style: TextStyle(fontWeight: FontWeight.w600, color: t.text)),
                                Text(
                                  '${Formatters.amount(view.amount)} ${a.symbol}${disabled ? ' · Disabled' : ''}',
                                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: t.muted),
                                ),
                              ],
                            ),
                          ),
                          NexIcon('chevR', size: 18, color: t.subtle),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _networkPicker(BuildContext context, WalletProvider provider) {
    final t = NexThemeScope.of(context);
    final a = asset!;
    final totalBalance = _balance(provider);
    return ColoredBox(
      color: t.appBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NexScreenHeader(title: 'Select Network', onBack: _back),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: NexLayout.horizontalPadding(context)),
              children: [
                Row(
                  children: [
                    CoinLogo(symbol: a.symbol, color: a.color, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name, style: TextStyle(fontWeight: FontWeight.w600, color: t.text)),
                          Text(a.symbol, style: TextStyle(fontSize: 12, color: t.muted)),
                        ],
                      ),
                    ),
                    Text(
                      _balanceLabel(provider, totalBalance, a.symbol),
                      style: TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: t.text),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const NexIcon('alert', size: 18, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pick the network that matches the recipient. Wrong network can mean lost funds.',
                          style: TextStyle(fontSize: 13, color: const Color(0xFFF59E0B).withValues(alpha: 0.95)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...a.networks.map((n) {
                  final feeLine = provider.feeLineFor(a.symbol, n);
                  final eta = kNetworkEta[n] ?? '';
                  final netBalance = _balanceForNetwork(provider, n);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NexCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () => setState(() {
                        network = n;
                        step = _SendStep.form;
                      }),
                      child: Row(
                        children: [
                          NetworkIcon(network: n, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n, style: TextStyle(fontWeight: FontWeight.w600, color: t.text)),
                                if (feeLine.isNotEmpty)
                                  Text(feeLine, style: TextStyle(fontSize: 12, color: t.muted))
                                else if (eta.isNotEmpty)
                                  Text(eta, style: TextStyle(fontSize: 12, color: t.muted)),
                                Text(
                                  _balanceLabel(provider, netBalance, a.symbol),
                                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: t.muted),
                                ),
                              ],
                            ),
                          ),
                          NexIcon('chevR', size: 18, color: t.subtle),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sendForm(BuildContext context, WalletProvider provider) {
    final t = NexThemeScope.of(context);
    final a = asset!;
    final n = network!;
    final balance = _networkBalance(provider);
    final price = _price(provider);
    final disabled = a.symbol == 'TRX';
    final locked = provider.pendingWithdrawal != null;
    final valid = !disabled && !locked && _address.text.trim().length > 10 && _amountNum > 0 && _amountNum <= balance;
    final fee = provider.feeDisplayFor(a.symbol, n);
    final eta = kNetworkEta[n] ?? '';
    final balanceLabel = 'Balance on $n';

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(
            title: 'Send ${a.symbol}',
            onBack: _back,
            right: NetBadge(network: n),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                if (disabled) _lockBanner(t, 'TRX withdrawal is disabled in futre. Your TRX balance still updates live from your linked NEX wallet.'),
                if (locked) _lockBanner(t, 'One withdrawal is already processing. You can create another withdrawal after it completes.'),
                Row(
                  children: [
                    const Expanded(child: NexLabel('Recipient Address')),
                    TextButton(
                      onPressed: disabled || locked ? null : _pasteRecipientAddress,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Paste',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.navActive),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _address,
                  enabled: !disabled && !locked,
                  maxLines: 2,
                  style: TextStyle(fontSize: 14, fontFamily: 'monospace', color: t.text),
                  decoration: InputDecoration(
                    hintText: 'Paste or scan $n address',
                    filled: true,
                    fillColor: t.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.inputBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.inputBorder)),
                    suffixIcon: disabled || locked
                        ? null
                        : IconButton(
                            tooltip: 'Scan QR code',
                            onPressed: _scanRecipientAddress,
                            icon: NexIcon('scan', size: 20, color: t.muted),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: NexLabel('Amount')),
                    Text(
                      '$balanceLabel ${Formatters.amount(balance)} ${a.symbol}',
                      style: TextStyle(fontSize: 12, color: t.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: t.inputFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.inputBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amount,
                          enabled: !disabled && !locked,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 20, color: t.text),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '0.00',
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (v) {
                            final cleaned = v.replaceAll(RegExp(r'[^0-9.]'), '');
                            if (cleaned != v) {
                              _amount.value = TextEditingValue(
                                text: cleaned,
                                selection: TextSelection.collapsed(offset: cleaned.length),
                              );
                            }
                            setState(() {});
                          },
                        ),
                      ),
                      Text(a.symbol, style: TextStyle(fontWeight: FontWeight.w600, color: t.text2)),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: disabled || locked ? null : () {
                          _amount.text = balance.toString();
                          setState(() {});
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: t.cardSoft,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('MAX', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.text)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '≈ \$${Formatters.usd(_amountNum * price)}${_amountNum > balance ? '  Insufficient balance' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _amountNum > balance ? const Color(0xFFF87171) : t.muted,
                  ),
                ),
                const SizedBox(height: 16),
                NexCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _detailRow(t, 'Network fee', fee),
                      _detailRow(t, 'Est. arrival', eta),
                      _detailRow(t, 'Network', n),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: NexLayout.flowFooterPadding(context),
            child: NexPrimaryButton(
              label: 'Review',
              onPressed: valid ? () => setState(() => step = _SendStep.review) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sendReview(BuildContext context, WalletProvider provider) {
    final t = NexThemeScope.of(context);
    final a = asset!;
    final n = network!;
    final addr = _address.text.trim();
    final amt = _amountNum;
    final price = _price(provider);
    final receiverGets = _receiverGets(provider, a.symbol);
    final fee = provider.feeDisplayFor(a.symbol, n);

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(title: 'Review', onBack: _back),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (submitError != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NexIcon('alert', size: 18, color: Color(0xFFEF4444)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            submitError!,
                            style: TextStyle(fontSize: 13, color: t.text, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Center(child: CoinLogo(symbol: a.symbol, color: a.color, size: 56)),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '${Formatters.amount(amt)} ${a.symbol}',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: t.text),
                  ),
                ),
                Center(
                  child: Text('≈ \$${Formatters.usd(amt * price)}', style: TextStyle(fontSize: 14, color: t.muted)),
                ),
                const SizedBox(height: 20),
                NexCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _detailRow(t, 'From', 'My NEX Wallet'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('To', style: TextStyle(fontSize: 14, color: t.text2)),
                          Flexible(
                            child: Text(
                              Formatters.shortenAddress(addr),
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.text),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _detailRow(t, 'Network', n),
                      Divider(color: t.divider, height: 24),
                      _detailRow(t, 'Amount', '${Formatters.amount(amt)} ${a.symbol}', mono: true),
                      _detailRow(t, 'Network fee', fee),
                      _detailRow(t, 'Receiver gets', '${Formatters.amount(receiverGets)} ${a.symbol}', mono: true),
                      Divider(color: t.divider, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total deducted', style: TextStyle(fontWeight: FontWeight.w600, color: t.text)),
                          Text('${Formatters.amount(amt)} ${a.symbol}', style: TextStyle(fontWeight: FontWeight.w600, color: t.text)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: NexLayout.flowFooterPadding(context),
            child: NexPrimaryButton(
              label: submitting ? 'Processing...' : 'Confirm & Send',
              loading: submitting,
              onPressed: submitting ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _withdrawalProgress(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final t = NexThemeScope.of(context);
    final a = asset!;
    final n = network!;
    final amt = _amountNum;
    final addr = _address.text.trim();
    final receiverGets = result?.netAmount?.toDouble() ?? _receiverGets(provider, a.symbol);
    final status = result?.status ?? 'pending_main_wallet';
    final feeNum = result?.fee?.toDouble() ?? provider.feeDeductionFor(a.symbol, n);
    final feeLabel = provider.feeDisplayFor(a.symbol, n);
    final txid = result?.txid;
    final allComplete = _withdrawalIsFullyComplete(status, txid);
    final activeStep = _withdrawalActiveStep(status);
    final submittedAt = _submittedAt ?? DateTime.now();

    void copy(String value, String label) {
      Clipboard.setData(ClipboardData(text: value));
      showNexToast(context, '$label copied');
    }

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(
            title: 'Withdrawal details',
            onBack: widget.onBack,
            right: NexIconButton(
              onTap: () => showNexComingSoon(context, 'Support'),
              icon: 'help',
              size: 18,
            ),
          ),
          Expanded(
            child: ListView(
              padding: NexLayout.screenPadding(context).copyWith(bottom: 24),
              children: [
                const SizedBox(height: 8),
                Center(child: CoinLogo(symbol: a.symbol, color: a.color, size: 64)),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Transfer to ${Formatters.shortenAddress(addr)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.muted),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '- ${Formatters.amount(amt)} ${a.symbol}',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: t.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: OutlinedButton(
                    onPressed: () => showNexComingSoon(context, 'Notify recipient'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.text,
                      side: BorderSide(color: t.divider),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Notify the Other Party', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                if (!allComplete) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: t.dark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: NexIcon('info', size: 18, color: Color(0xFF22C55E)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Transaction can take up to 30 minutes to complete successfully.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.text,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (submitting) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: t.text),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Status updates automatically.',
                            style: TextStyle(fontSize: 13, color: t.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                NexCard(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _withdrawalTimeline(t, activeStep: activeStep, allComplete: allComplete),
                ),
                const SizedBox(height: 16),
                NexCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _withdrawalDetailRow(t, 'Type', 'Withdrawal on-chain'),
                      _withdrawalDetailRow(
                        t,
                        'Time',
                        _formatWithdrawalTimestamp(submittedAt),
                      ),
                      _withdrawalDetailRow(
                        t,
                        'Receiving',
                        '${Formatters.amount(receiverGets)} ${a.symbol}',
                      ),
                      _withdrawalDetailRow(
                        t,
                        'Network fee',
                        feeNum > 0
                            ? '${Formatters.amount(feeNum)} ${a.symbol}'
                            : (feeLabel != '—' ? feeLabel : 'Network fee'),
                      ),
                      _withdrawalNetworkRow(t, n),
                      _withdrawalCopyRow(
                        t,
                        'Withdrawal address',
                        Formatters.shortenAddress(addr, head: 10, tail: 8),
                        addr,
                        onCopy: copy,
                      ),
                      _withdrawalCopyRow(
                        t,
                        'TXID',
                        txid != null && txid.isNotEmpty
                            ? Formatters.shortenAddress(txid, head: 10, tail: 8)
                            : '—',
                        txid ?? '',
                        onCopy: copy,
                      ),
                      if (result?.id != null && result!.id > 0)
                        _withdrawalDetailRow(t, 'Reference', '#${result!.id}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: NexLayout.flowFooterPadding(context),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: widget.onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.text,
                  side: BorderSide(color: t.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _withdrawalActiveStep(String status) {
    final value = status.toLowerCase();
    if (['completed', 'confirmed', 'success', 'sent'].contains(value)) return 3;
    if (['processing', 'broadcast_unknown'].contains(value)) return 2;
    return 1;
  }

  String _formatWithdrawalTimestamp(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  Widget _withdrawalTimeline(
    NexTokens t, {
    required int activeStep,
    required bool allComplete,
  }) {
    const steps = ['Confirming', 'Under Review', 'Processing', 'Sent'];

    return Column(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final label = entry.value;
        final done = allComplete || i < activeStep || i == 0;
        final current = !allComplete && i == activeStep;
        final isLast = i == steps.length - 1;
        final subtitle = _withdrawalStepSubtitle(label, current: current, activeStep: activeStep, allComplete: allComplete);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    _withdrawalTimelineDot(t, done: done, current: current),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: done ? const Color(0xFF22C55E) : t.divider,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: current || (done && isLast) ? FontWeight.w700 : FontWeight.w500,
                          color: done || current ? t.text : t.muted,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: t.muted, height: 1.35),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String? _withdrawalStepSubtitle(
    String label, {
    required bool current,
    required int activeStep,
    required bool allComplete,
  }) {
    if (allComplete) return null;
    if (label == 'Under Review' && (current || activeStep == 1)) {
      return 'Can take up to 30 min';
    }
    if (label == 'Processing' && (current || activeStep == 2)) {
      return 'Broadcasting to the network';
    }
    if (label == 'Sent' && current) {
      return 'Waiting for confirmation';
    }
    return null;
  }

  Widget _withdrawalTimelineDot(NexTokens t, {required bool done, required bool current}) {
    if (done) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
        child: const Center(child: NexIcon('check', size: 12, color: Colors.white)),
      );
    }
    if (current) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF22C55E), width: 2),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
          ),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: t.divider, width: 2),
      ),
    );
  }

  Widget _withdrawalDetailRow(NexTokens t, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 14, color: t.muted)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _withdrawalNetworkRow(NexTokens t, String network) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text('Network', style: TextStyle(fontSize: 14, color: t.muted)),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                NetworkIcon(network: network, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    networkLabel(network),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _withdrawalCopyRow(
    NexTokens t,
    String label,
    String display,
    String copyValue, {
    required void Function(String value, String label) onCopy,
  }) {
    if (copyValue.isEmpty) {
      return _withdrawalDetailRow(t, label, display);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 14, color: t.muted)),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    display,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.text,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => onCopy(copyValue, label),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: NexIcon('copy', size: 16, color: t.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockBanner(NexTokens t, String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NexCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NexIcon('lock', size: 20, color: Color(0xFFF59E0B)),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: TextStyle(fontSize: 14, color: t.text2))),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(NexTokens t, String key, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: TextStyle(fontSize: 14, color: t.text2)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: mono ? 'monospace' : null,
                color: t.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NexSwapFlow extends StatefulWidget {
  const NexSwapFlow({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<NexSwapFlow> createState() => _NexSwapFlowState();
}

class _NexSwapFlowState extends State<NexSwapFlow> {
  String fromId = 'btc';
  String toId = 'usdt';
  String fromNet = 'ERC20';
  String toNet = 'TRC20';
  final _amount = TextEditingController();
  SwapEstimateResult? quote;
  Map<String, dynamic>? exchange;
  bool loading = false;
  bool done = false;
  String? error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  AssetDefinition get _from => assetById(fromId)!;
  AssetDefinition get _to => assetById(toId)!;

  String _fromNetwork() => _from.symbol == 'USDT' ? fromNet : _from.networks.first;
  String _toNetwork() => _to.symbol == 'USDT' ? toNet : _to.networks.first;

  bool get _samePair => _from.symbol == _to.symbol && _fromNetwork() == _toNetwork();

  double get _amountNum => double.tryParse(_amount.text.trim()) ?? 0;

  double _balance(WalletProvider provider, String id) {
    return provider.assetViews
        .firstWhere((v) => v.definition.id == id, orElse: () => provider.assetViews.first)
        .amount;
  }

  double _price(WalletProvider provider, String id) {
    return provider.assetViews
        .firstWhere((v) => v.definition.id == id, orElse: () => provider.assetViews.first)
        .price;
  }

  double? _quotedOutput() {
    final est = quote?.estimate;
    if (est != null) {
      for (final key in ['amount', 'amountTo', 'estimatedAmount', 'estimatedAmountTo']) {
        final value = est[key];
        if (value == null) continue;
        final parsed = double.tryParse('$value');
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    final estAmt = exchange?['estimatedAmount'] ?? exchange?['estimated_amount'];
    if (estAmt != null) {
      final parsed = double.tryParse('$estAmt');
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  double _outputAmount(WalletProvider provider) {
    final quoted = _quotedOutput();
    if (quoted != null) return quoted;
    final fromPrice = _price(provider, fromId);
    final toPrice = _price(provider, toId);
    if (_amountNum <= 0 || toPrice <= 0) return 0;
    return _amountNum * (fromPrice / toPrice) * 0.997;
  }

  void _clearQuoteFields() {
    quote = null;
    exchange = null;
    error = null;
  }

  void _resetQuote() => setState(_clearQuoteFields);

  void _flip() {
    setState(() {
      final prevFromId = fromId;
      final prevToId = toId;
      final prevFromNet = fromNet;
      final prevToNet = toNet;
      fromId = prevToId;
      toId = prevFromId;
      fromNet = prevToNet;
      toNet = prevFromNet;
      _amount.clear();
      quote = null;
      exchange = null;
      error = null;
    });
  }

  Future<void> _loadQuote() async {
    if (_amountNum <= 0 || _samePair) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await context.read<WalletProvider>().swapEstimate(
            fromAsset: _from.symbol,
            fromNetwork: _fromNetwork(),
            toAsset: _to.symbol,
            toNetwork: _toNetwork(),
            amount: _amount.text.trim(),
          );
      if (!mounted) return;
      setState(() => quote = result);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      setState(() {
        quote = null;
        error = message;
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _createExchange() async {
    if (_amountNum <= 0 || _amountNum > _balance(context.read<WalletProvider>(), fromId) || _samePair) {
      return;
    }

    final authed = await authenticateSensitiveAction(
      context,
      reason: 'Confirm swap of ${Formatters.amount(_amountNum)} ${_from.symbol}',
    );
    if (!authed || !mounted) return;

    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await context.read<WalletProvider>().swapExchange(
            fromAsset: _from.symbol,
            fromNetwork: _fromNetwork(),
            toAsset: _to.symbol,
            toNetwork: _toNetwork(),
            amount: _amount.text.trim(),
          );
      if (!mounted) return;
      final row = data['exchange'];
      setState(() {
        exchange = row is Map<String, dynamic> ? row : data;
        done = true;
      });
      showNexToast(context, 'Swap exchange created');
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
      setState(() => error = message);
      showNexError(context, message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _swapAgain() {
    setState(() {
      done = false;
      _amount.clear();
      quote = null;
      exchange = null;
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (done) {
            _swapAgain();
          } else {
            widget.onBack();
          }
        }
      },
      child: done ? _doneScreen(context) : _formScreen(context),
    );
  }

  Widget _formScreen(BuildContext context) {
    final t = NexThemeScope.of(context);
    final provider = context.watch<WalletProvider>();
    final out = _outputAmount(provider);
    final fromBal = _balance(provider, fromId);
    final toPrice = _price(provider, toId);

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(title: 'Swap', onBack: widget.onBack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                NexCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NexLabel('From', color: t.muted),
                      const SizedBox(height: 12),
                      _assetPicker(
                        t: t,
                        selectedId: fromId,
                        usdtNet: fromNet,
                        onAsset: (id) => setState(() {
                          fromId = id;
                          _clearQuoteFields();
                        }),
                        onNetwork: (net) => setState(() {
                          fromNet = net;
                          _clearQuoteFields();
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amount,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(fontSize: 26, fontFamily: 'monospace', color: t.text),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: '0.00',
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (_) => _resetQuote(),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() => _amount.text = Formatters.amount(fromBal));
                              _resetQuote();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: t.cardSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('MAX', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.text)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Balance ${Formatters.amount(fromBal)} ${_from.symbol}',
                        style: TextStyle(fontSize: 12, color: t.muted, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Material(
                    color: t.secondaryBg,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _flip,
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: t.appBg, width: 4),
                        ),
                        child: NexIcon('refresh', size: 18, color: t.secondaryText),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                NexCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NexLabel('To', color: t.muted),
                      const SizedBox(height: 12),
                      _assetPicker(
                        t: t,
                        selectedId: toId,
                        usdtNet: toNet,
                        onAsset: (id) => setState(() {
                          toId = id;
                          _clearQuoteFields();
                        }),
                        onNetwork: (net) => setState(() {
                          toNet = net;
                          _clearQuoteFields();
                        }),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _amountNum > 0 ? Formatters.amount(out) : '0.00',
                        style: TextStyle(
                          fontSize: 26,
                          fontFamily: 'monospace',
                          color: _amountNum > 0 ? t.text : t.subtle,
                        ),
                      ),
                    ],
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F1D1D).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(error!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 12),
                NexCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _swapRow(
                        t,
                        'Rate',
                        quote != null
                            ? 'Live quote from SimpleSwap'
                            : 'Preview: 1 ${_from.symbol} ≈ ${Formatters.amount(_price(provider, fromId) / (toPrice == 0 ? 1 : toPrice))} ${_to.symbol}',
                        mono: true,
                      ),
                      _swapRow(t, 'Provider', 'SimpleSwap'),
                      _swapRow(
                        t,
                        'Receive',
                        _amountNum > 0 ? '${Formatters.amount(out)} ${_to.symbol}' : '0.00',
                        mono: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: NexLayout.flowFooterPadding(context),
            child: Column(
              children: [
                NexSecondaryButton(
                  label: loading ? 'Checking...' : 'Get live quote',
                  onPressed: (!_amountNum.isFinite || _amountNum <= 0 || _samePair || loading) ? () {} : _loadQuote,
                ),
                const SizedBox(height: 8),
                NexPrimaryButton(
                  label: 'Create exchange',
                  loading: loading,
                  onPressed: (!_amountNum.isFinite ||
                          _amountNum <= 0 ||
                          _amountNum > fromBal ||
                          _samePair ||
                          loading)
                      ? null
                      : _createExchange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _doneScreen(BuildContext context) {
    final t = NexThemeScope.of(context);
    final provider = context.watch<WalletProvider>();
    final out = _outputAmount(provider);
    final addressFrom = exchange?['addressFrom'] ??
        exchange?['address_from'] ??
        exchange?['depositAddress'] ??
        exchange?['payinAddress'];
    final publicId = exchange?['publicId'] ?? exchange?['public_id'];
    final extraId = exchange?['extraIdFrom'] ?? exchange?['extra_id_from'];

    return ColoredBox(
      color: t.appBg,
      child: Column(
        children: [
          NexScreenHeader(title: 'Swap', onBack: _swapAgain),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(color: Color(0xFFFBBF24), shape: BoxShape.circle),
                        child: const Center(child: NexIcon('refresh', size: 28, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Exchange created',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: t.text),
                ),
                const SizedBox(height: 8),
                Text(
                  '${Formatters.amount(_amountNum)} ${_from.symbol} → ${Formatters.amount(out)} ${_to.symbol}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.text2, fontFamily: 'monospace'),
                ),
                if (publicId != null) ...[
                  const SizedBox(height: 16),
                  NexCard(
                    padding: const EdgeInsets.all(16),
                    child: _swapRow(t, 'Exchange ID', '$publicId', mono: true),
                  ),
                ],
                const SizedBox(height: 16),
                NexCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NexLabel('Send exactly', color: t.muted),
                      const SizedBox(height: 8),
                      Text(
                        '${Formatters.amount(_amountNum)} ${_from.symbol}',
                        style: TextStyle(fontSize: 22, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: t.text),
                      ),
                      const SizedBox(height: 16),
                      NexLabel('To SimpleSwap address', color: t.muted),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.cardSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          addressFrom?.toString() ?? 'Waiting for provider deposit address',
                          style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: t.text),
                        ),
                      ),
                      if (extraId != null) ...[
                        const SizedBox(height: 12),
                        _swapRow(t, 'Payment ID / memo', '$extraId', mono: true),
                      ],
                      const SizedBox(height: 12),
                      NexSecondaryButton(
                        label: 'Copy address',
                        onPressed: addressFrom == null
                            ? () {}
                            : () {
                                Clipboard.setData(ClipboardData(text: '$addressFrom'));
                                showNexToast(context, 'Deposit address copied');
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                NexCard(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'After SimpleSwap receives the deposit, it will send the target asset to your NEX receive address. Do not send from the wrong network.',
                    style: TextStyle(fontSize: 12, color: t.text2, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: NexLayout.flowFooterPadding(context),
            child: NexPrimaryButton(label: 'Swap again', onPressed: _swapAgain),
          ),
        ],
      ),
    );
  }

  Widget _assetPicker({
    required NexTokens t,
    required String selectedId,
    required String usdtNet,
    required ValueChanged<String> onAsset,
    required ValueChanged<String> onNetwork,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kSwappableAssets.map((asset) {
            final active = selectedId == asset.id;
            return GestureDetector(
              onTap: () => onAsset(asset.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? t.pillActiveBg : t.pillIdleBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CoinLogo(symbol: asset.symbol, color: asset.color, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      asset.symbol,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active ? t.pillActiveText : t.pillIdleText,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (assetById(selectedId)?.symbol == 'USDT') ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kUsdtSwapNetworks.map((network) {
              final active = usdtNet == network;
              return GestureDetector(
                onTap: () => onNetwork(network),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? t.pillActiveBg : t.pillIdleBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NetworkIcon(network: network, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        network,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: active ? t.pillActiveText : t.pillIdleText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _swapRow(NexTokens t, String key, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: TextStyle(fontSize: 14, color: t.text2)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: mono ? 'monospace' : null,
                color: t.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
