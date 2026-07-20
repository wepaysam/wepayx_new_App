import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../core/utils/formatters.dart';
import '../../models/wallet_model.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final items = provider.activity;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Activity',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No activity yet'),
                subtitle: Text('Deposits, withdrawals, and swaps will appear here.'),
              ),
            )
          else
            ...items.map((item) => _ActivityTile(item: item)),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final ActivityItem item;

  Color _statusColor() {
    if (['completed', 'confirmed', 'success'].contains(item.status)) {
      return Colors.green;
    }
    if (['processing', 'pending_main_wallet', 'pending'].contains(item.status)) {
      return Colors.amber;
    }
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final asset = assetBySymbol(item.asset);
    final sent = item.type == 'sent';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _showDetails(context),
        leading: CoinAvatar(symbol: asset.symbol, color: asset.color),
        title: Text('${sent ? 'Sent' : 'Received'} ${item.asset}'),
        subtitle: Text('${item.network} · ${Formatters.time(item.createdAt)}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${sent ? '-' : '+'}${Formatters.amount(item.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: sent ? Colors.redAccent : Colors.green,
              ),
            ),
            Text(
              item.status.replaceAll('_', ' '),
              style: TextStyle(fontSize: 11, color: _statusColor()),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transaction', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _detailRow('Amount', '${Formatters.amount(item.amount)} ${item.asset}'),
              _detailRow('Network', item.network),
              _detailRow('Status', item.status),
              if (item.txid != null) _detailRow('Tx ID', Formatters.shortId(item.txid!)),
              if (item.toAddress != null) _detailRow('To', Formatters.shortenAddress(item.toAddress!)),
              if (item.createdAt != null) _detailRow('Time', Formatters.dateTime(item.createdAt)),
              if (item.txid != null)
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: item.txid!));
                    showAppSnackBar(context, 'Tx ID copied');
                  },
                  child: const Text('Copy transaction ID'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
