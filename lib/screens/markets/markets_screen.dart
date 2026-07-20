import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../core/utils/formatters.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common.dart';

class MarketsScreen extends StatelessWidget {
  const MarketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final marketRows = kMarketSymbols.map((symbol) {
      final live = provider.prices[symbol];
      final asset = assetBySymbol(symbol);
      return (
        symbol: symbol,
        name: asset.name,
        color: asset.color,
        price: live?.price ?? asset.defaultPrice,
        change: live?.change24h ?? 0,
      );
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Markets',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          ...marketRows.map((row) {
            final positive = row.change >= 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CoinAvatar(symbol: row.symbol, color: row.color),
                title: Text(row.name),
                subtitle: Text(row.symbol),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${Formatters.usd(row.price)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${positive ? '+' : ''}${Formatters.percent(row.change)}%',
                      style: TextStyle(
                        color: positive ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
