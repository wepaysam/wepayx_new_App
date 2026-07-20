class CryptoPrice {
  const CryptoPrice({
    required this.price,
    this.change24h,
  });

  final double price;
  final double? change24h;

  factory CryptoPrice.fromJson(Map<String, dynamic> json) {
    return CryptoPrice(
      price: _toDouble(json['price']),
      change24h: json['change24h'] == null ? null : _toDouble(json['change24h']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}

class CryptoPricesSnapshot {
  const CryptoPricesSnapshot({
    required this.prices,
    this.updatedAt,
    this.source,
    this.stale = false,
  });

  final Map<String, CryptoPrice> prices;
  final String? updatedAt;
  final String? source;
  final bool stale;

  factory CryptoPricesSnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['prices'] as Map<String, dynamic>? ?? {};
    return CryptoPricesSnapshot(
      prices: raw.map(
        (key, value) => MapEntry(
          key,
          CryptoPrice.fromJson(value as Map<String, dynamic>),
        ),
      ),
      updatedAt: json['updatedAt'] as String?,
      source: json['source'] as String?,
      stale: json['stale'] == true,
    );
  }
}

class PopupNotification {
  const PopupNotification({
    required this.id,
    required this.title,
    this.body,
    this.asset,
    this.network,
    this.amount,
    this.kind,
    this.createdAt,
  });

  final int id;
  final String title;
  final String? body;
  final String? asset;
  final String? network;
  final String? amount;
  final String? kind;
  final String? createdAt;

  factory PopupNotification.fromJson(Map<String, dynamic> json) {
    return PopupNotification(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      asset: json['asset'] as String?,
      network: json['network'] as String?,
      amount: json['amount']?.toString(),
      kind: json['kind'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

class WithdrawalFeeInfo {
  const WithdrawalFeeInfo({
    required this.assetKey,
    required this.symbol,
    required this.type,
    this.fee,
    required this.display,
  });

  final String assetKey;
  final String symbol;
  final String type;
  final double? fee;
  final String display;

  bool get isNetworkFee => type == 'network';

  factory WithdrawalFeeInfo.fromJson(Map<String, dynamic> json) {
    return WithdrawalFeeInfo(
      assetKey: json['assetKey'] as String? ?? '',
      symbol: (json['symbol'] as String? ?? '').toUpperCase(),
      type: json['type'] as String? ?? 'fixed',
      fee: json['fee'] == null ? null : _toDouble(json['fee']),
      display: json['display'] as String? ??
          json['feeDisplay'] as String? ??
          json['feeLabel'] as String? ??
          '',
    );
  }

  double deductionAmount(String assetSymbol) {
    if (isNetworkFee || fee == null) return 0;
    final sym = assetSymbol.toUpperCase();
    if (sym == 'USDT' || sym == 'USDC') return fee!;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}

class DepositAddressResult {
  const DepositAddressResult({
    required this.asset,
    required this.network,
    required this.depositAddress,
    this.mainWalletAddress,
    this.addressSource,
    this.custodyMode,
  });

  final String asset;
  final String network;
  final String depositAddress;
  final String? mainWalletAddress;
  final String? addressSource;
  final String? custodyMode;

  factory DepositAddressResult.fromJson(Map<String, dynamic> json) {
    return DepositAddressResult(
      asset: json['asset'] as String? ?? '',
      network: json['network'] as String? ?? '',
      depositAddress: json['depositAddress'] as String? ?? '',
      mainWalletAddress: json['mainWalletAddress'] as String?,
      addressSource: json['addressSource'] as String?,
      custodyMode: json['custodyMode'] as String?,
    );
  }
}

class WithdrawalResult {
  const WithdrawalResult({
    required this.id,
    required this.status,
    required this.asset,
    required this.network,
    required this.amount,
    this.fee,
    this.netAmount,
    this.txid,
  });

  final int id;
  final String status;
  final String asset;
  final String network;
  final String amount;
  final num? fee;
  final num? netAmount;
  final String? txid;

  factory WithdrawalResult.fromJson(Map<String, dynamic> json) {
    return WithdrawalResult(
      id: _toInt(json['id']),
      status: json['status'] as String? ?? 'processing',
      asset: json['asset'] as String? ?? '',
      network: json['network'] as String? ?? '',
      amount: json['amount']?.toString() ?? '0',
      fee: _toNum(json['fee']),
      netAmount: _toNum(json['netAmount'] ?? json['net_amount']),
      txid: json['txid'] as String?,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static num? _toNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse('$value');
  }
}

class FearGreedIndex {
  const FearGreedIndex({
    required this.value,
    required this.classification,
  });

  final int value;
  final String classification;

  String get shortLabel {
    final c = classification.toLowerCase();
    if (c.contains('fear')) return 'FEAR';
    if (c.contains('greed')) return 'GREED';
    return 'NEUTRAL';
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.minBuild,
    required this.apkUrl,
    this.releaseNotes = '',
    this.forceUpdate = false,
    this.platform = 'android',
  });

  final String latestVersion;
  final int latestBuild;
  final int minBuild;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final String platform;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: json['latestVersion'] as String? ?? '1.0.0',
      latestBuild: _toInt(json['latestBuild']),
      minBuild: _toInt(json['minBuild']),
      apkUrl: json['apkUrl'] as String? ?? '',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      forceUpdate: json['forceUpdate'] == true,
      platform: json['platform'] as String? ?? 'android',
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

class SwapEstimateResult {
  const SwapEstimateResult({
    this.estimate,
    this.range,
    this.rangeError,
  });

  final Map<String, dynamic>? estimate;
  final Map<String, dynamic>? range;
  final String? rangeError;

  factory SwapEstimateResult.fromJson(Map<String, dynamic> json) {
    return SwapEstimateResult(
      estimate: json['estimate'] as Map<String, dynamic>?,
      range: json['range'] as Map<String, dynamic>?,
      rangeError: json['rangeError'] as String?,
    );
  }
}
