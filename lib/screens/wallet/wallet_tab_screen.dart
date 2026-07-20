import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common.dart';

class WalletTabScreen extends StatelessWidget {
  const WalletTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Wallet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            provider.user?.email ?? '',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Portfolio value'),
                  const SizedBox(height: 8),
                  Text(
                    provider.balanceVisible
                        ? '\$${Formatters.usd(provider.totalUsd)}'
                        : '••••••',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Holdings'),
          const SizedBox(height: 12),
          ...provider.assetViews.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CoinAvatar(symbol: item.definition.symbol, color: item.definition.color),
                title: Text('${item.definition.symbol} · ${item.definition.networks.join(', ')}'),
                subtitle: Text('${Formatters.amount(item.amount)} ${item.definition.symbol}'),
                trailing: Text(
                  provider.balanceVisible ? '\$${Formatters.usd(item.usd)}' : '••••',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          if (provider.pendingWithdrawal != null) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.hourglass_top, color: Colors.amber),
                title: const Text('Pending withdrawal'),
                subtitle: Text(
                  '${provider.pendingWithdrawal!.amount} ${provider.pendingWithdrawal!.asset} · ${provider.pendingWithdrawal!.status}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
