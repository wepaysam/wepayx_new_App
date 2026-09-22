import 'package:flutter/material.dart';

class AssetDefinition {
  const AssetDefinition({
    required this.id,
    required this.name,
    required this.symbol,
    required this.color,
    required this.networks,
    this.defaultPrice = 0,
  });

  final String id;
  final String name;
  final String symbol;
  final Color color;
  final List<String> networks;
  final double defaultPrice;
}

const kSupportedAssets = [
  AssetDefinition(
    id: 'btc',
    name: 'Bitcoin',
    symbol: 'BTC',
    color: Color(0xFFF97316),
    networks: ['Bitcoin'],
    defaultPrice: 64200,
  ),
  AssetDefinition(
    id: 'eth',
    name: 'Ethereum',
    symbol: 'ETH',
    color: Color(0xFF6366F1),
    networks: ['ERC20'],
    defaultPrice: 1848.65,
  ),
  AssetDefinition(
    id: 'trx',
    name: 'TRON',
    symbol: 'TRX',
    color: Color(0xFFEF4444),
    networks: ['TRC20'],
    defaultPrice: 0.28,
  ),
  AssetDefinition(
    id: 'usdt',
    name: 'Tether',
    symbol: 'USDT',
    color: Color(0xFF22C55E),
    networks: ['ERC20', 'TRC20', 'BEP20'],
    defaultPrice: 1,
  ),
  AssetDefinition(
    id: 'bnb',
    name: 'BNB',
    symbol: 'BNB',
    color: Color(0xFFEAB308),
    networks: ['BEP20'],
    defaultPrice: 600,
  ),
  AssetDefinition(
    id: 'usdc',
    name: 'USD Coin',
    symbol: 'USDC',
    color: Color(0xFF3B82F6),
    networks: ['ERC20'],
    defaultPrice: 1,
  ),
];

const kMarketSymbols = ['BTC', 'ETH', 'SOL', 'BNB', 'QNT', 'RENDER', 'ETC', 'USDT', 'USDC', 'TRX'];

const kSwappableAssetIds = ['btc', 'eth', 'bnb', 'usdt', 'usdc'];

const kUsdtSwapNetworks = ['ERC20', 'TRC20', 'BEP20'];

List<AssetDefinition> get kSwappableAssets =>
    kSwappableAssetIds.map((id) => assetById(id)!).toList();

const kNetworkEta = {
  'TRC20': '~1 min',
  'BEP20': '~30 sec',
  'ERC20': '~2 min',
  'Bitcoin': '~20 min',
};

AssetDefinition assetBySymbol(String symbol) {
  return kSupportedAssets.firstWhere(
    (a) => a.symbol == symbol.toUpperCase(),
    orElse: () => kSupportedAssets.firstWhere((a) => a.symbol == 'USDT'),
  );
}

AssetDefinition? assetById(String id) {
  for (final asset in kSupportedAssets) {
    if (asset.id == id) return asset;
  }
  return null;
}

/// Maps NEX ledger keys (`USDT_TRON`) to app asset + network (`USDT` / `TRC20`).
({String asset, String network}) appAssetFromLedger(
  String raw, {
  String? network,
}) {
  final key = raw.toUpperCase().replaceAll('-', '_').trim();
  if (network != null &&
      network.isNotEmpty &&
      !key.contains('_') &&
      key != 'USDT' &&
      key != 'USDC') {
    return (asset: key, network: network);
  }
  switch (key) {
    case 'USDT_TRON':
    case 'USDT_TRC20':
      return (asset: 'USDT', network: 'TRC20');
    case 'USDT_BNB':
    case 'USDT_BEP20':
    case 'USDT_BSC':
      return (asset: 'USDT', network: 'BEP20');
    case 'USDT_ERC':
    case 'USDT_ERC20':
    case 'USDT_ETH':
      return (asset: 'USDT', network: 'ERC20');
    case 'USDC_ERC':
    case 'USDC_ERC20':
    case 'USDC_ETH':
      return (asset: 'USDC', network: 'ERC20');
    case 'TRX':
    case 'TRON':
      return (asset: 'TRX', network: 'TRC20');
    case 'ETH':
      return (asset: 'ETH', network: 'ERC20');
    case 'BNB':
      return (asset: 'BNB', network: 'BEP20');
    case 'BTC':
    case 'BTC_BITCOIN':
      return (asset: 'BTC', network: 'Bitcoin');
    default:
      if (key.contains('_')) {
        final parts = key.split('_');
        return (asset: parts.first, network: parts.sublist(1).join('_'));
      }
      return (asset: key, network: network ?? '');
  }
}

String? withdrawalAssetKey(String symbol, String network) {
  switch ('${symbol.toUpperCase()}_$network') {
    case 'USDT_TRC20':
      return 'USDT_TRON';
    case 'USDT_BEP20':
      return 'USDT_BNB';
    case 'USDT_ERC20':
      return 'USDT_ERC';
    case 'USDC_ERC20':
      return 'USDC_ERC';
    case 'BTC_Bitcoin':
      return 'BTC';
    case 'ETH_ERC20':
      return 'ETH';
    case 'BNB_BEP20':
      return 'BNB';
    default:
      return null;
  }
}

String networkLabel(String network) {
  switch (network) {
    case 'TRC20':
      return 'TRON (TRC-20)';
    case 'BEP20':
      return 'BNB Smart Chain (BEP-20)';
    case 'ERC20':
      return 'Ethereum (ERC-20)';
    case 'Bitcoin':
      return 'Bitcoin';
    default:
      return network;
  }
}
