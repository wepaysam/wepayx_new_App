import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common.dart';

class SendFlow extends StatefulWidget {
  const SendFlow({super.key});

  @override
  State<SendFlow> createState() => _SendFlowState();
}

class _SendFlowState extends State<SendFlow> {
  AssetDefinition? asset;
  String? network;
  final _amount = TextEditingController();
  final _address = TextEditingController();
  bool submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (asset == null || network == null) return;
    if (_amount.text.trim().isEmpty || _address.text.trim().length < 12) {
      showAppSnackBar(context, 'Enter amount and valid address');
      return;
    }

    setState(() => submitting = true);
    try {
      final result = await context.read<WalletProvider>().withdraw(
            asset: asset!.symbol,
            network: network!,
            amount: _amount.text.trim(),
            toAddress: _address.text.trim(),
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Withdrawal submitted'),
          content: Text(
            '${result.amount} ${result.asset} on ${result.network}\nStatus: ${result.status}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Send')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (asset == null) ...[
            const SectionLabel('Select asset'),
            const SizedBox(height: 12),
            ...kSupportedAssets.where((a) => a.symbol != 'TRX').map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CoinAvatar(symbol: item.symbol, color: item.color),
                      title: Text(item.name),
                      onTap: () => setState(() {
                        asset = item;
                        network = null;
                      }),
                    ),
                  ),
                ),
          ] else if (network == null) ...[
            Text('${asset!.symbol} · choose network', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...asset!.networks.where((n) => !(asset!.symbol == 'TRX' && n == 'TRC20')).map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(networkLabel(item)),
                      subtitle: const Text('Fee from API'),
                      onTap: () => setState(() => network = item),
                    ),
                  ),
                ),
          ] else ...[
            if (provider.pendingWithdrawal != null)
              Card(
                color: Colors.amber.withValues(alpha: 0.12),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: const Text('Withdrawal in progress'),
                  subtitle: Text(
                    '#${provider.pendingWithdrawal!.id} · ${provider.pendingWithdrawal!.status}',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (${asset!.symbol})',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Recipient address'),
            ),
            const SizedBox(height: 8),
            Text(
              'Fee: see API',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: submitting || provider.pendingWithdrawal != null ? null : _submit,
              child: submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Review & send'),
            ),
          ],
        ],
      ),
    );
  }
}
