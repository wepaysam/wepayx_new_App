import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common.dart';
import '../receive/receive_flow.dart';
import '../send/send_flow.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: provider.refreshWallet,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                const NexLogo(size: 40),
                const Spacer(),
                IconButton(
                  onPressed: provider.toggleTheme,
                  icon: Icon(provider.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                ),
                IconButton(
                  onPressed: provider.toggleBalanceVisible,
                  icon: Icon(provider.balanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionLabel('Total balance'),
            const SizedBox(height: 6),
            Text(
              provider.balanceVisible ? '\$${Formatters.usd(provider.totalUsd)}' : '••••••',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 24),
            _ActionGrid(
              onReceive: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReceiveFlow()),
              ),
              onSend: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SendFlow()),
              ),
              onSwap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Swap is temporarily unavailable. It will return in a later update.',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const SectionLabel('Your assets'),
            const SizedBox(height: 12),
            ...provider.assetViews.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CoinAvatar(symbol: item.definition.symbol, color: item.definition.color),
                  title: Text(item.definition.name),
                  subtitle: Text(item.definition.symbol),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        provider.balanceVisible
                            ? Formatters.amount(item.amount)
                            : '••••',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        provider.balanceVisible
                            ? '\$${Formatters.usd(item.usd)}'
                            : '••••',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onReceive,
    required this.onSend,
    required this.onSwap,
  });

  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Receive', Icons.call_received, onReceive),
      ('Send', Icons.north_east, onSend),
      ('Swap', Icons.swap_horiz, onSwap),
      ('Buy', Icons.credit_card, () {}),
      ('History', Icons.history, () {}),
      ('More', Icons.more_horiz, () {}),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: actions.map((action) {
        return InkWell(
          onTap: action.$3,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).cardTheme.color,
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.$2),
                const SizedBox(height: 8),
                Text(action.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
