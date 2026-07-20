import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  AssetDefinition fromAsset = kSupportedAssets.firstWhere((a) => a.symbol == 'USDT');
  AssetDefinition toAsset = kSupportedAssets.firstWhere((a) => a.symbol == 'BTC');
  String fromNetwork = 'TRC20';
  String toNetwork = 'Bitcoin';
  final _amount = TextEditingController();
  Map<String, dynamic>? estimate;
  bool loading = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _estimate() async {
    if (_amount.text.trim().isEmpty) {
      showAppSnackBar(context, 'Enter an amount');
      return;
    }
    setState(() => loading = true);
    try {
      final result = await context.read<WalletProvider>().swapEstimate(
            fromAsset: fromAsset.symbol,
            fromNetwork: fromNetwork,
            toAsset: toAsset.symbol,
            toNetwork: toNetwork,
            amount: _amount.text.trim(),
          );
      setState(() => estimate = result.estimate);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Swap')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _AssetPicker(
            label: 'From',
            asset: fromAsset,
            network: fromNetwork,
            onChanged: (asset, network) => setState(() {
              fromAsset = asset;
              fromNetwork = network;
            }),
          ),
          const SizedBox(height: 12),
          _AssetPicker(
            label: 'To',
            asset: toAsset,
            network: toNetwork,
            onChanged: (asset, network) => setState(() {
              toAsset = asset;
              toNetwork = network;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Amount (${fromAsset.symbol})'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: loading ? null : _estimate,
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Get estimate'),
          ),
          if (estimate != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Estimated receive: ${estimate!['amount'] ?? estimate!['estimatedAmount'] ?? '—'} ${toAsset.symbol}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssetPicker extends StatelessWidget {
  const _AssetPicker({
    required this.label,
    required this.asset,
    required this.network,
    required this.onChanged,
  });

  final String label;
  final AssetDefinition asset;
  final String network;
  final void Function(AssetDefinition asset, String network) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            DropdownButtonFormField<AssetDefinition>(
              value: asset,
              decoration: const InputDecoration(labelText: 'Asset'),
              items: kSupportedAssets
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text('${item.symbol} · ${item.name}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                onChanged(value, value.networks.first);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: network,
              decoration: const InputDecoration(labelText: 'Network'),
              items: asset.networks
                  .map((item) => DropdownMenuItem(value: item, child: Text(networkLabel(item))))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                onChanged(asset, value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
