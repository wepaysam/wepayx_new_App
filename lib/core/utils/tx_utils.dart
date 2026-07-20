import 'package:flutter/material.dart';

String txStatusText(String? status) {
  final value = status ?? 'confirmed';
  if (['completed', 'confirmed', 'success'].contains(value)) {
    return 'Transaction successful';
  }
  if (['processing', 'pending_main_wallet', 'broadcast_unknown', 'pending'].contains(value)) {
    return 'Transaction is processing';
  }
  if (['refunded', 'failed', 'withdrawal_failed'].contains(value)) {
    return 'Transaction failed';
  }
  return value.replaceAll('_', ' ');
}

Color txStatusColor(String? status) {
  final value = status ?? 'confirmed';
  if (['completed', 'confirmed', 'success'].contains(value)) {
    return const Color(0xFF22C55E);
  }
  if (['processing', 'pending_main_wallet', 'broadcast_unknown', 'pending'].contains(value)) {
    return const Color(0xFFF59E0B);
  }
  return const Color(0xFFEF4444);
}

String? explorerUrl(String network, String? txid) {
  if (txid == null || txid.isEmpty || txid.startsWith('futre-withdrawal-')) return null;
  switch (network) {
    case 'TRC20':
      return 'https://tronscan.org/#/transaction/$txid';
    case 'BEP20':
      return 'https://bscscan.com/tx/$txid';
    case 'ERC20':
      return 'https://etherscan.io/tx/$txid';
    case 'Bitcoin':
      return 'https://blockstream.info/tx/$txid';
    default:
      return null;
  }
}

double parseTxFee(String? fee) {
  if (fee == null || fee.isEmpty) return 0;
  return double.tryParse(fee.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
}

bool txIsPending(String? status) {
  return [
    'processing',
    'pending_main_wallet',
    'broadcast_unknown',
    'pending',
    'queued',
  ].contains(status ?? '');
}
