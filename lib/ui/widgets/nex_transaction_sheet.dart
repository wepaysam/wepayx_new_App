import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/assets.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/tx_utils.dart';
import '../../models/wallet_model.dart';
import '../../providers/wallet_provider.dart';
import '../nex_layout.dart';
import '../nex_tokens.dart';
import 'nex_brand.dart';
import 'nex_components.dart';

Future<void> showNexTransactionSheet(
  BuildContext context, {
  required ActivityItem tx,
}) {
  final tokens = NexThemeScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => NexThemeScope(
      tokens: tokens,
      child: _NexTransactionSheet(tx: tx),
    ),
  );
}

class _NexTransactionSheet extends StatelessWidget {
  const _NexTransactionSheet({required this.tx});

  final ActivityItem tx;

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);
    final provider = context.watch<WalletProvider>();
    final asset = assetBySymbol(tx.asset);
    final network = tx.network.isNotEmpty ? tx.network : asset.networks.first;
    final txid = tx.txid ?? tx.reference ?? tx.id;
    final fee = parseTxFee(tx.fee);
    final amount = tx.amount;
    final price = provider.prices[asset.symbol]?.price ?? asset.defaultPrice;
    final usd = amount * price;
    final userEmail = provider.user?.email ?? 'My NEX Wallet';
    final isPending = txIsPending(tx.status);
    final explorer = explorerUrl(network, txid);

    void copy(String value, String label) {
      Clipboard.setData(ClipboardData(text: value));
      showNexToast(context, '$label copied');
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(20, 10, 20, 28 + NexLayout.systemBottomInset(context)),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: t.muted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    isPending ? 'Transaction Submitted' : 'Transaction Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: t.text),
                  ),
                  if (!isPending)
                    Positioned(
                      right: 0,
                      child: Material(
                        color: t.cardSoft,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Center(child: NexIcon('x', size: 18, color: t.text2)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (isPending) ...[
                const SizedBox(height: 12),
                Center(
                  child: Material(
                    color: t.cardSoft,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => copy(txid, 'Transaction ID'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ID: ${Formatters.shortId(txid)}',
                              style: TextStyle(fontSize: 13, color: t.text2, fontFamily: 'monospace'),
                            ),
                            const SizedBox(width: 8),
                            NexIcon('copy', size: 15, color: t.muted),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 20),
                Center(
                  child: TokenNetworkLogo(
                    symbol: asset.symbol,
                    network: network,
                    color: asset.color,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '\$${Formatters.usd(usd)}',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: t.text),
                  ),
                ),
                Center(
                  child: Text(
                    '${Formatters.amount(amount)} ${asset.symbol}',
                    style: TextStyle(fontSize: 15, color: t.text2),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: Text(
                  isPending ? 'Transaction is processing' : txStatusText(tx.status),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: txStatusColor(tx.status),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (isPending) _detailRow(t, 'Estimated arrival', '5 min≈'),
              if (!isPending) _detailRow(t, 'Type', tx.type == 'received' ? 'Received' : 'Sent'),
              if (!isPending && tx.createdAt != null)
                _detailRow(t, 'Date', Formatters.dateTime(tx.createdAt)),
              _copyRow(
                t,
                'From',
                Formatters.shortenAddress(tx.fromAddress ?? userEmail, head: 9, tail: 6),
                tx.fromAddress ?? userEmail,
                onCopy: copy,
              ),
              _copyRow(
                t,
                'To',
                Formatters.shortenAddress(tx.toAddress ?? tx.reference ?? '—', head: 9, tail: 6),
                tx.toAddress ?? tx.reference ?? '',
                onCopy: copy,
              ),
              _networkRow(t, network),
              if (!isPending)
                _detailRow(t, 'Fee', fee > 0 ? '\$${Formatters.usd(fee)}' : 'Network fee'),
              if (!isPending)
                _copyRow(
                  t,
                  'Transaction ID',
                  Formatters.shortId(txid),
                  txid,
                  onCopy: copy,
                ),
              if (isPending) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: t.cardSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _detailRow(t, 'Amount debited', '${Formatters.amount(amount)} ${asset.symbol}'),
                      const SizedBox(height: 12),
                      _detailRow(
                        t,
                        'Fee deducted',
                        fee > 0 ? '${Formatters.amount(fee)} ${asset.symbol}' : 'Network fee',
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (isPending)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.text,
                      side: BorderSide(color: t.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: explorer == null
                      ? null
                      : () async {
                          final uri = Uri.parse(explorer);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                  child: Text(
                    'View Transaction on Explorer',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: explorer == null ? t.muted : t.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(NexTokens t, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 14, color: t.text2)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _copyRow(
    NexTokens t,
    String label,
    String display,
    String copyValue, {
    required void Function(String value, String label) onCopy,
  }) {
    if (copyValue.isEmpty) {
      return _detailRow(t, label, display);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 14, color: t.text2)),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    display,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.text),
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

  Widget _networkRow(NexTokens t, String network) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text('Network', style: TextStyle(fontSize: 14, color: t.text2)),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                NetworkIcon(network: network, size: 22),
                const SizedBox(width: 8),
                Text(
                  networkLabel(network),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
