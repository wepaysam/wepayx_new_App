import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/tx_utils.dart';
import '../../models/wallet_model.dart';
import '../../providers/wallet_provider.dart';
import '../nex_layout.dart';
import '../nex_tokens.dart';
import '../widgets/nex_brand.dart';
import '../widgets/nex_transaction_sheet.dart';
import '../widgets/nex_components.dart';
import 'nex_account_support_screens.dart';

class MarketChip {
  const MarketChip({
    required this.sym,
    required this.color,
    required this.change,
  });
  final String sym;
  final Color color;
  final double change;
}

const marketScrollChips = [
  MarketChip(sym: 'SOL', color: Color(0xFF8B5CF6), change: 5.7),
  MarketChip(sym: 'QNT', color: Color(0xFF06B6D4), change: 3.1),
  MarketChip(sym: 'ETC', color: Color(0xFF16A34A), change: 0.9),
  MarketChip(sym: 'RENDER', color: Color(0xFFEF4444), change: -2.3),
];

const marketListSeed = [
  ('BTC', 'Bitcoin', Color(0xFFF97316)),
  ('ETH', 'Ethereum', Color(0xFF6366F1)),
  ('SOL', 'Solana', Color(0xFF8B5CF6)),
  ('BNB', 'BNB', Color(0xFFEAB308)),
  ('QNT', 'Quant', Color(0xFF06B6D4)),
  ('RENDER', 'Render', Color(0xFFEF4444)),
  ('ETC', 'Ethereum Classic', Color(0xFF16A34A)),
  ('USDT', 'Tether', Color(0xFF22C55E)),
];

Color _fearGreedColor(int? value) {
  if (value == null) return const Color(0xFF94A3B8);
  if (value <= 25) return const Color(0xFFF87171);
  if (value <= 45) return const Color(0xFFFB923C);
  if (value <= 55) return const Color(0xFFFACC15);
  if (value <= 75) return const Color(0xFF86EFAC);
  return const Color(0xFF22C55E);
}

class NexHomeScreen extends StatefulWidget {
  const NexHomeScreen({
    super.key,
    required this.onReceive,
    required this.onSend,
    required this.onSwap,
    required this.onBuy,
    required this.onHistory,
    required this.onProfile,
    required this.onNotifications,
    required this.onAssetDetail,
    required this.onAccountSupport,
  });

  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback onSwap;
  final VoidCallback onBuy;
  final VoidCallback onHistory;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  final void Function(String assetId) onAssetDetail;
  final VoidCallback onAccountSupport;

  @override
  State<NexHomeScreen> createState() => _NexHomeScreenState();
}

class _NexHomeScreenState extends State<NexHomeScreen> {
  String tab = 'assets';
  bool promoOpen = true;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final provider = context.watch<WalletProvider>();
    final hPad = NexLayout.horizontalPadding(context);

    final sendBlocked = provider.isFeatureBlocked('withdrawal');
    final receiveBlocked = provider.isFeatureBlocked('deposit');
    final swapBlocked = provider.isFeatureBlocked('swap');

    final actions = [
      ('Receive', 'downLeft', widget.onReceive, receiveBlocked),
      ('Send', 'upRight', widget.onSend, sendBlocked),
      ('Swap', 'refresh', widget.onSwap, swapBlocked),
      ('Buy', 'card', widget.onBuy, false),
      ('History', 'clock', widget.onHistory, false),
      ('More', 'more', widget.onProfile, false),
    ];

    return ColoredBox(
      color: t.homeBg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 8),
            child: Row(
              children: [
                Material(
                  color: t.iconBtnBg,
                  shape: const CircleBorder(),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(child: NexLogo(size: 26, strokeWidth: 2.6)),
                  ),
                ),
                const Spacer(),
                NexIconButton(
                  onTap: provider.toggleTheme,
                  icon: provider.isDark ? 'sun' : 'moon',
                ),
                const SizedBox(width: 8),
                NexIconButton(onTap: widget.onNotifications, icon: 'bell'),
                const SizedBox(width: 8),
                NexIconButton(onTap: widget.onProfile, icon: 'settings'),
              ],
            ),
          ),
          if (provider.accountStatus?.hasRestrictions == true)
            NexAccountRestrictionBanner(
              status: provider.accountStatus!,
              onSupport: widget.onAccountSupport,
            ),
          if (provider.announcements.isNotEmpty)
            NexAnnouncementBanner(
              announcement: provider.announcements.firstWhere(
                (item) => item.isHighPriority,
                orElse: () => provider.announcements.first,
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 4),
            child: Row(
              children: [
                const NexLabel('Total Balance'),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: provider.toggleBalanceVisible,
                  child: NexIcon(
                    provider.balanceVisible ? 'eye' : 'eyeOff',
                    size: 15,
                    color: t.muted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Text(
              provider.balanceVisible
                  ? '\$${Formatters.usd(provider.totalUsd)}'
                  : '••••••',
              style: TextStyle(
                fontSize: NexLayout.balanceFontSize(context),
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: t.text,
              ),
            ),
          ),
          if (sendBlocked)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
              child: Row(
                children: [
                  // Aligns under the middle (Send) column — left side of Send.
                  const Spacer(flex: 1),
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Material(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            final status = provider.accountStatus;
                            if (status != null) {
                              NexAccountRestrictionBanner(
                                status: status,
                                onSupport: widget.onAccountSupport,
                              ).showInfo(context);
                            }
                          },
                          child: const SizedBox(
                            width: 28,
                            height: 28,
                            child: Center(
                              child: NexIcon(
                                'info',
                                size: 14,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, sendBlocked ? 8 : 20, hPad, 0),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
              children: actions.map((a) {
                final blocked = a.$4;
                final iconColor = blocked ? t.muted : t.text;
                final labelColor = blocked ? t.muted : t.text2;
                return Material(
                  color: t.dark
                      ? Colors.white.withValues(alpha: blocked ? 0.03 : 0.05)
                      : (blocked ? const Color(0xFFF8FAFC) : Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: blocked
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                          : (t.dark ? Colors.transparent : t.cardBorder),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: a.$3,
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              NexIcon(a.$2, size: 20, color: iconColor),
                              const SizedBox(height: 6),
                              Text(
                                a.$1,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: labelColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (blocked)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: NexIcon(
                              'lock',
                              size: 12,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (promoOpen) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: NexCard(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  children: [
                    Positioned(
                      right: -24,
                      top: -32,
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0x88F97316),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        onPressed: () => setState(() => promoOpen = false),
                        icon: NexIcon('x', size: 16, color: t.muted),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NexLabel('Tip', color: Color(0xFFFB923C)),
                        const SizedBox(height: 4),
                        Text(
                          'Diversify your assets securely',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: t.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Spread holdings across networks to reduce single-chain risk.',
                          style: TextStyle(fontSize: 13, color: t.text2),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFB923C),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: t.dark
                                    ? Colors.white.withValues(alpha: 0.20)
                                    : const Color(0xFFCBD5E1),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: t.dark
                                    ? Colors.white.withValues(alpha: 0.20)
                                    : const Color(0xFFCBD5E1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: NexLabel('Market'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                NexCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: SizedBox(
                    width: 78,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${provider.fearGreed?.value ?? '—'}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _fearGreedColor(provider.fearGreed?.value),
                          ),
                        ),
                        Text(
                          provider.fearGreed?.shortLabel ?? 'FEAR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: t.muted,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ...marketScrollChips.map((c) {
                  final live = provider.prices[c.sym];
                  final ch = live?.change24h ?? c.change;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: NexCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: SizedBox(
                        width: 78,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CoinLogo(symbol: c.sym, color: c.color, size: 28),
                            const SizedBox(height: 4),
                            Text(
                              c.sym,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: t.text,
                              ),
                            ),
                            Text(
                              '${ch >= 0 ? '+' : ''}${Formatters.percent(ch)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: ch >= 0
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFF87171),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: t.cardSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: ['assets', 'accounts'].map((name) {
                  final active = tab == name;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => tab = name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: active
                              ? (t.dark ? Colors.white : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: active && !t.dark
                              ? const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          name[0].toUpperCase() + name.substring(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? (t.dark ? Colors.black : t.text)
                                : t.text2,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          ...provider.assetViews.map((item) {
            return InkWell(
              onTap: () => widget.onAssetDetail(item.definition.id),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    CoinLogo(
                      symbol: item.definition.symbol,
                      color: item.definition.color,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.definition.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: t.text,
                            ),
                          ),
                          Text(
                            '${Formatters.amount(item.amount)} ${item.definition.symbol}${tab == 'accounts' && item.definition.networks.length > 1 ? ' · ${item.definition.networks.length} networks' : ''}',
                            style: TextStyle(fontSize: 12, color: t.muted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          provider.balanceVisible
                              ? '\$${Formatters.usd(item.usd)}'
                              : '••••',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: t.text,
                          ),
                        ),
                        Text(
                          provider.balanceVisible
                              ? '${Formatters.amount(item.amount)} ${item.definition.symbol}'
                              : '••••',
                          style: TextStyle(fontSize: 12, color: t.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class NexMarketsScreen extends StatefulWidget {
  const NexMarketsScreen({super.key});

  @override
  State<NexMarketsScreen> createState() => _NexMarketsScreenState();
}

class _NexMarketsScreenState extends State<NexMarketsScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final provider = context.watch<WalletProvider>();
    final q = _query.text.toLowerCase();
    final rows = marketListSeed.where(
      (r) => ('${r.$1}${r.$2}').toLowerCase().contains(q),
    );

    return ColoredBox(
      color: t.appBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NexScreenHeader(title: 'Markets'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 15, color: t.text),
              decoration: InputDecoration(
                hintText: 'Search coins',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: NexIcon('search', size: 18, color: t.muted),
                ),
                filled: true,
                fillColor: t.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: t.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: t.inputBorder),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    provider.pricesStale
                        ? 'Prices may be delayed'
                        : provider.pricesSource == 'coinbase'
                        ? 'Live prices · Coinbase'
                        : 'Live prices · CoinMarketCap',
                    style: TextStyle(fontSize: 12, color: t.muted),
                  ),
                ),
                if (provider.pricesUpdatedAt != null)
                  Text(
                    _priceAgeLabel(provider.pricesUpdatedAt!),
                    style: TextStyle(fontSize: 11, color: t.subtle),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                SizedBox(width: 28, child: NexLabel('#', color: t.muted)),
                Expanded(child: NexLabel('Name', color: t.muted)),
                NexLabel('Price · 24h', color: t.muted),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<WalletProvider>().refreshPrices(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  ...rows.toList().asMap().entries.map((entry) {
                    final i = entry.key;
                    final row = entry.value;
                    final live = provider.prices[row.$1];
                    final price =
                        live?.price ?? assetBySymbol(row.$1).defaultPrice;
                    final ch = live?.change24h ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(fontSize: 13, color: t.muted),
                            ),
                          ),
                          CoinLogo(symbol: row.$1, color: row.$3, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.$2,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: t.text,
                                  ),
                                ),
                                Text(
                                  row.$1,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: t.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${Formatters.usd(price)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: t.text,
                                ),
                              ),
                              Text(
                                '${ch > 0 ? '+' : ''}${Formatters.percent(ch)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: ch > 0
                                      ? const Color(0xFF22C55E)
                                      : ch < 0
                                      ? const Color(0xFFF87171)
                                      : t.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No coins match "${_query.text}"',
                          style: TextStyle(color: t.muted),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _priceAgeLabel(String iso) {
    final updated = DateTime.tryParse(iso);
    if (updated == null) return '';
    final mins = DateTime.now().toUtc().difference(updated.toUtc()).inMinutes;
    if (mins < 1) return 'Just now';
    if (mins < 60) return '${mins}m ago';
    final local = updated.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class NexWalletTabScreen extends StatelessWidget {
  const NexWalletTabScreen({super.key, required this.onAssetDetail});

  final void Function(String assetId) onAssetDetail;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final provider = context.watch<WalletProvider>();

    return ColoredBox(
      color: t.appBg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const NexScreenHeader(title: 'Wallet'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: NexCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NexLabel('Portfolio Value'),
                  const SizedBox(height: 4),
                  Text(
                    provider.balanceVisible
                        ? '\$${Formatters.usd(provider.totalUsd)}'
                        : '••••••',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: t.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: NexLabel('Assets'),
          ),
          const SizedBox(height: 8),
          ...provider.assetViews.map((item) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: NexCard(
                padding: const EdgeInsets.all(14),
                onTap: () => onAssetDetail(item.definition.id),
                child: Row(
                  children: [
                    CoinLogo(
                      symbol: item.definition.symbol,
                      color: item.definition.color,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.definition.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: t.text,
                            ),
                          ),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: item.definition.networks
                                .map((n) => NetBadge(network: n))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${Formatters.usd(item.usd)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: t.text,
                          ),
                        ),
                        Text(
                          '${Formatters.amount(item.amount)} ${item.definition.symbol}',
                          style: TextStyle(fontSize: 12, color: t.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class NexActivityScreen extends StatefulWidget {
  const NexActivityScreen({super.key});

  @override
  State<NexActivityScreen> createState() => _NexActivityScreenState();
}

class _NexActivityScreenState extends State<NexActivityScreen> {
  String filter = 'All';
  static const filters = ['All', 'Sent', 'Received', 'Swapped'];

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final provider = context.watch<WalletProvider>();
    final rows = provider.activity.where((x) {
      if (filter == 'All') return true;
      if (filter == 'Sent') return x.type == 'sent';
      if (filter == 'Received') return x.type == 'received';
      return x.type == 'swapped';
    });

    return ColoredBox(
      color: t.appBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NexScreenHeader(title: 'Activity'),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: filters.map((f) {
                final active = filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: active ? t.pillActiveBg : t.pillIdleBg,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => filter = f),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active ? t.pillActiveText : t.pillIdleText,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        'Nothing here yet.',
                        style: TextStyle(color: t.muted),
                      ),
                    ),
                  )
                else
                  ...rows.map((x) => NexActivityListTile(tx: x)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NexActivityListTile extends StatelessWidget {
  const NexActivityListTile({super.key, required this.tx});

  final ActivityItem tx;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final provider = context.watch<WalletProvider>();
    final asset = assetBySymbol(tx.asset);
    final meta = tx.type == 'received'
        ? ('downLeft', const Color(0xFF22C55E), 'Received')
        : tx.type == 'sent'
        ? ('upRight', const Color(0xFFEF4444), 'Sent')
        : ('refresh', const Color(0xFF3B82F6), 'Swapped');
    final statusColor = txStatusColor(tx.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NexCard(
        padding: const EdgeInsets.all(14),
        onTap: () => showNexTransactionSheet(context, tx: tx),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: meta.$2.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Center(child: NexIcon(meta.$1, size: 20, color: meta.$2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${meta.$3} ${asset.symbol}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                  Row(
                    children: [
                      NetBadge(network: tx.network),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tx.status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${tx.type == 'received' ? '+' : '-'}${Formatters.amount(tx.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tx.type == 'received'
                        ? const Color(0xFF22C55E)
                        : tx.type == 'sent'
                        ? const Color(0xFFF87171)
                        : t.text,
                  ),
                ),
                Text(
                  provider.balanceVisible
                      ? '\$${Formatters.usd(tx.amount * asset.defaultPrice)}'
                      : '••••',
                  style: TextStyle(fontSize: 12, color: t.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NexAssetDetailScreen extends StatelessWidget {
  const NexAssetDetailScreen({
    super.key,
    required this.assetId,
    required this.onBack,
  });

  final String assetId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final provider = context.watch<WalletProvider>();
    final definition = assetById(assetId) ?? kSupportedAssets.first;
    final view = provider.assetViews.firstWhere(
      (item) => item.definition.id == assetId,
      orElse: () => provider.assetViews.first,
    );
    final networkBalances = provider.wallet.balances
        .where((row) => row.asset == definition.symbol)
        .toList();
    final transactions = provider.activity
        .where((item) => item.asset == definition.symbol)
        .toList();
    final showNetworkBreakdown =
        definition.networks.length > 1 && networkBalances.isNotEmpty;

    String formatAmount(double amount) {
      if (!provider.balanceVisible) return '••••';
      return '${Formatters.amount(amount)} ${definition.symbol}';
    }

    String formatUsd(double usd) {
      if (!provider.balanceVisible) return '••••';
      return '\$${Formatters.usd(usd)}';
    }

    return ColoredBox(
      color: t.appBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NexScreenHeader(title: definition.name, onBack: onBack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                NexCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CoinLogo(
                        symbol: definition.symbol,
                        color: definition.color,
                        size: 48,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatAmount(view.amount),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: t.text,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatUsd(view.usd),
                              style: TextStyle(fontSize: 14, color: t.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (showNetworkBreakdown) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: NexLabel('Balance by network'),
                  ),
                  ...definition.networks.map((network) {
                    final rows = networkBalances.where(
                      (row) => row.network == network,
                    );
                    final amount = rows.fold(
                      0.0,
                      (sum, row) => sum + row.balance,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: NexCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            NetworkIcon(network: network, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    network,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: t.text,
                                    ),
                                  ),
                                  Text(
                                    networkLabel(network),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: t.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatAmount(amount),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: t.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: NexLabel('Transactions'),
                ),
                if (transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No transactions yet.',
                        style: TextStyle(color: t.muted, fontSize: 14),
                      ),
                    ),
                  )
                else
                  ...transactions.map((tx) => NexActivityListTile(tx: tx)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
