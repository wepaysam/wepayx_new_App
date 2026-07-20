import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/assets.dart';
import '../../models/api_models.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/common.dart';

class ReceiveFlow extends StatefulWidget {
  const ReceiveFlow({super.key});

  @override
  State<ReceiveFlow> createState() => _ReceiveFlowState();
}

class _ReceiveFlowState extends State<ReceiveFlow> {
  AssetDefinition? selectedAsset;
  String? selectedNetwork;
  DepositAddressResult? result;
  bool loading = false;

  Future<void> _loadAddress() async {
    if (selectedAsset == null || selectedNetwork == null) return;
    setState(() => loading = true);
    try {
      final data = await context.read<WalletProvider>().depositAddress(
            asset: selectedAsset!.symbol,
            network: selectedNetwork!,
          );
      setState(() => result = data);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (selectedAsset == null) ...[
            const SectionLabel('Select asset'),
            const SizedBox(height: 12),
            ...kSupportedAssets.where((a) => a.symbol != 'TRX').map(
                  (asset) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CoinAvatar(symbol: asset.symbol, color: asset.color),
                      title: Text(asset.name),
                      subtitle: Text(asset.symbol),
                      onTap: () => setState(() {
                        selectedAsset = asset;
                        selectedNetwork = null;
                        result = null;
                      }),
                    ),
                  ),
                ),
          ] else if (selectedNetwork == null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CoinAvatar(symbol: selectedAsset!.symbol, color: selectedAsset!.color),
              title: Text(selectedAsset!.name),
              subtitle: const Text('Choose network'),
            ),
            const SizedBox(height: 12),
            ...selectedAsset!.networks.where((n) => n != 'TRC20' || selectedAsset!.symbol != 'TRX').map(
                  (network) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(networkLabel(network)),
                      subtitle: const Text('Fee from API'),
                      onTap: () async {
                        setState(() => selectedNetwork = network);
                        await _loadAddress();
                      },
                    ),
                  ),
                ),
          ] else if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (result != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: result!.depositAddress,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${selectedAsset!.symbol} on ${networkLabel(selectedNetwork!)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SelectableText(result!.depositAddress),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: result!.depositAddress));
                  showAppSnackBar(context, 'Address copied');
                },
                child: const Text('Copy address'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
