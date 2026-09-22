class CryptoPrice {
  const CryptoPrice({required this.price, this.change24h});

  final double price;
  final double? change24h;

  factory CryptoPrice.fromJson(Map<String, dynamic> json) {
    return CryptoPrice(
      price: _toDouble(json['price']),
      change24h: json['change24h'] == null
          ? null
          : _toDouble(json['change24h']),
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
        (key, value) =>
            MapEntry(key, CryptoPrice.fromJson(value as Map<String, dynamic>)),
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
    final rawId = json['id'];
    return PopupNotification(
      id: rawId is int ? rawId : int.tryParse('$rawId') ?? 0,
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

class NotificationPopupResult {
  const NotificationPopupResult({
    required this.ok,
    this.telegramMessageId,
    this.error,
    this.blocked = false,
    this.isFrozen = false,
  });

  final bool ok;
  final String? telegramMessageId;
  final String? error;
  final bool blocked;
  final bool isFrozen;

  bool get isRestricted =>
      error == 'user_restricted_or_blocked' || blocked || isFrozen;

  factory NotificationPopupResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final userMap = user is Map ? Map<String, dynamic>.from(user) : const {};
    return NotificationPopupResult(
      ok: json['ok'] == true,
      telegramMessageId: json['telegram_message_id']?.toString(),
      error: json['error']?.toString(),
      blocked: userMap['blocked'] == true,
      isFrozen: userMap['is_frozen'] == true || userMap['isFrozen'] == true,
    );
  }
}

/// Withdrawal fee row from `GET /api/fees`.
///
/// The live API prices fees in USD (`feeAsset: "USD"`) and may return a
/// percentage override instead of a flat amount.
class WithdrawalFeeInfo {
  const WithdrawalFeeInfo({
    required this.assetKey,
    required this.symbol,
    required this.type,
    this.fee,
    this.feeUsd,
    this.percent,
    this.networkFee,
    this.serviceFee,
    this.feeAsset = 'USD',
    required this.display,
    this.timeframeText,
    this.estimatedSeconds,
    this.aliases = const [],
  });

  final String assetKey;
  final String symbol;
  final String type;
  final double? fee;
  final double? feeUsd;
  final double? percent;
  final double? networkFee;
  final double? serviceFee;
  final String feeAsset;
  final String display;
  final String? timeframeText;
  final int? estimatedSeconds;

  /// Every key this row answers to (`USDT_TRC20`, `USDT_TRON`, ...).
  final List<String> aliases;

  bool get isPercentFee => percent != null && percent! > 0;

  /// True when the fee amount is denominated in USD rather than the asset.
  bool get isUsdFee => feeAsset.toUpperCase() == 'USD';

  factory WithdrawalFeeInfo.fromJson(Map<String, dynamic> json) {
    final assetKey = json['assetKey'] as String? ?? '';
    final keys = <String>{
      assetKey,
      if (json['canonicalAssetKey'] is String) json['canonicalAssetKey'] as String,
      if (json['legacyAssetKey'] is String) json['legacyAssetKey'] as String,
      ...(json['aliases'] as List<dynamic>? ?? []).map((item) => '$item'),
    }..removeWhere((key) => key.isEmpty);

    return WithdrawalFeeInfo(
      assetKey: assetKey,
      symbol: (json['symbol'] as String? ?? '').toUpperCase(),
      type: json['type'] as String? ?? 'fixed',
      fee: json['fee'] == null ? null : _toDouble(json['fee']),
      feeUsd: json['feeUsd'] == null ? null : _toDouble(json['feeUsd']),
      percent: json['percent'] == null ? null : _toDouble(json['percent']),
      networkFee: json['networkFee'] == null
          ? null
          : _toDouble(json['networkFee']),
      serviceFee: json['serviceFee'] == null
          ? null
          : _toDouble(json['serviceFee']),
      feeAsset: json['feeAsset'] as String? ?? 'USD',
      display:
          json['feeDisplay'] as String? ??
          json['display'] as String? ??
          json['feeLabel'] as String? ??
          '',
      timeframeText:
          json['timeframeText'] as String? ??
          json['timeframe'] as String? ??
          json['estimatedTime'] as String?,
      estimatedSeconds: json['estimatedSeconds'] == null
          ? null
          : _toDouble(json['estimatedSeconds']).round(),
      aliases: keys.toList(),
    );
  }

  /// Fee charged for [amount], expressed in the asset being sent.
  ///
  /// [priceUsd] converts USD-denominated fees into asset units, so USDT/USDC
  /// (price 1) deduct the USD amount unchanged.
  double deductionAmount({required double amount, required double priceUsd}) {
    if (isPercentFee) {
      return amount * (percent! / 100);
    }
    final flat = fee ?? feeUsd ?? networkFee;
    if (flat == null || flat <= 0) return 0;
    if (!isUsdFee) return flat;
    if (priceUsd <= 0) return 0;
    return flat / priceUsd;
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
  const FearGreedIndex({required this.value, required this.classification});

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

class SecurityLock {
  const SecurityLock({
    required this.feature,
    this.lockedUntil,
    this.reason,
  });

  final String feature;
  final DateTime? lockedUntil;
  final String? reason;

  bool get isActive {
    final until = lockedUntil;
    if (until == null) return true;
    return until.isAfter(DateTime.now());
  }

  bool matchesFeature(String feature) {
    final a = this.feature.toLowerCase();
    final b = feature.toLowerCase();
    if (a == b) return true;
    if (b == 'withdrawal' && a.contains('withdrawal')) return true;
    if (b == 'swap' && a.contains('swap')) return true;
    return false;
  }

  factory SecurityLock.fromJson(Map<String, dynamic> json) {
    return SecurityLock(
      feature: json['feature']?.toString() ?? '',
      lockedUntil: AccountStatusInfo._parseLockedUntil(
        json['locked_until'] ?? json['lockedUntil'],
      ),
      reason: json['reason']?.toString(),
    );
  }
}

class AccountStatusInfo {
  const AccountStatusInfo({
    required this.status,
    required this.isRestricted,
    required this.isFrozen,
    required this.message,
    required this.blockedFeatures,
    required this.affectedFeatures,
    required this.supportRequired,
    this.lockedUntil,
    this.securityLocks = const [],
    this.canWithdraw = true,
    this.telegramId,
  });

  final String status;
  final bool isRestricted;
  final bool isFrozen;
  final String message;
  final Map<String, bool> blockedFeatures;
  final List<String> affectedFeatures;
  final bool supportRequired;
  final DateTime? lockedUntil;
  final List<SecurityLock> securityLocks;
  final bool canWithdraw;
  final String? telegramId;

  /// Admin/account restriction (inactive wallet, freeze, pending delete).
  bool get hasRestrictions => isRestricted || isFrozen;

  /// Temporary hold from password reset / security_locks — not a ban.
  bool get hasSecurityHold {
    if (!canWithdraw) return true;
    return securityLocks.any((lock) => lock.isActive);
  }

  bool get isSecurityLocked {
    final until = lockedUntil;
    if (until != null && until.isAfter(DateTime.now())) return true;
    return hasSecurityHold;
  }

  bool blocks(String feature) {
    if (blockedFeatures[feature] == true) return true;
    final key = feature.toLowerCase();
    return securityLocks.any(
      (lock) => lock.isActive && lock.matchesFeature(key),
    );
  }

  AccountStatusInfo withLockedUntil(DateTime? until) {
    return AccountStatusInfo(
      status: status,
      isRestricted: isRestricted,
      isFrozen: isFrozen,
      message: message,
      blockedFeatures: {
        ...blockedFeatures,
        'withdrawal': true,
        'swap': true,
      },
      affectedFeatures: affectedFeatures.contains('withdrawal')
          ? affectedFeatures
          : [...affectedFeatures, 'withdrawal', 'swap'],
      supportRequired: supportRequired,
      lockedUntil: until ?? lockedUntil,
      securityLocks: securityLocks,
      canWithdraw: false,
      telegramId: telegramId,
    );
  }

  factory AccountStatusInfo.fromJson(Map<String, dynamic> json) {
    final rawBlocked = json['blockedFeatures'];
    final blocked = <String, bool>{};
    if (rawBlocked is Map) {
      rawBlocked.forEach((key, value) {
        blocked['$key'] = value == true;
      });
    }

    return AccountStatusInfo(
      status: json['status']?.toString() ?? 'active',
      isRestricted: json['isRestricted'] == true,
      isFrozen: json['isFrozen'] == true,
      message: json['message']?.toString() ?? '',
      blockedFeatures: blocked,
      affectedFeatures: (json['affectedFeatures'] as List<dynamic>? ?? [])
          .map((item) => '$item')
          .toList(),
      supportRequired: json['supportRequired'] == true,
      lockedUntil: _parseLockedUntil(json['locked_until'] ?? json['lockedUntil']),
      canWithdraw: json['canWithdraw'] != false && json['can_withdraw'] != false,
    );
  }

  factory AccountStatusInfo.fromUserCheck(Map<String, dynamic> json) {
    final restricted = json['restricted'] == true;
    final frozen = json['is_frozen'] == true || json['isFrozen'] == true;
    final blocked = json['blocked'] == true;
    final deletePending =
        json['delete_pending'] == true || json['deletePending'] == true;
    final canWithdraw = json['can_withdraw'] != false;
    final locks = (json['security_locks'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SecurityLock.fromJson)
        .toList();
    final activeLocks = locks.where((lock) => lock.isActive).toList();
    final withdrawLocked = !canWithdraw ||
        activeLocks.any((lock) => lock.matchesFeature('withdrawal'));
    final swapLocked =
        activeLocks.any((lock) => lock.matchesFeature('swap'));
    final blockedFeatures = <String, bool>{
      if (withdrawLocked || restricted || frozen || blocked || deletePending)
        'withdrawal': true,
      if (restricted || frozen || blocked || deletePending) 'deposit': true,
      if (swapLocked || restricted || frozen || blocked || deletePending)
        'swap': true,
    };
    final status = deletePending
        ? 'pending_delete'
        : frozen
        ? 'frozen'
        : restricted
        ? 'restricted'
        : 'active';
    final lockMessage = activeLocks
        .map((lock) => lock.reason)
        .whereType<String>()
        .where((reason) => reason.trim().isNotEmpty)
        .toList();
    final freezeReason = json['freeze_reason']?.toString();
    return AccountStatusInfo(
      status: status,
      isRestricted: restricted || blocked || deletePending,
      isFrozen: frozen,
      message: freezeReason?.trim().isNotEmpty == true
          ? freezeReason!
          : (lockMessage.isNotEmpty ? lockMessage.first : ''),
      blockedFeatures: blockedFeatures,
      affectedFeatures: blockedFeatures.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList(),
      supportRequired: restricted || frozen || blocked || deletePending,
      lockedUntil: activeLocks
          .map((lock) => lock.lockedUntil)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (latest, next) {
            if (latest == null || next.isAfter(latest)) return next;
            return latest;
          }),
      securityLocks: locks,
      canWithdraw: canWithdraw,
      telegramId: json['telegram_id']?.toString(),
    );
  }

  static DateTime? _parseLockedUntil(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      final ms = value > 2000000000 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    if (value is num) {
      final n = value.toInt();
      final ms = n > 2000000000 ? n : n * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}

class SupportTicket {
  const SupportTicket({
    required this.publicId,
    required this.status,
    required this.priority,
  });

  final String publicId;
  final String status;
  final String priority;

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      publicId: json['publicId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      priority: json['priority']?.toString() ?? 'normal',
    );
  }
}

class AppAnnouncement {
  const AppAnnouncement({
    required this.title,
    required this.body,
    required this.kind,
    required this.priority,
    required this.requiresAck,
  });

  final String title;
  final String body;
  final String kind;
  final String priority;
  final bool requiresAck;

  bool get isHighPriority => priority.toLowerCase() == 'high';

  factory AppAnnouncement.fromJson(Map<String, dynamic> json) {
    return AppAnnouncement(
      title: json['title']?.toString() ?? 'Announcement',
      body: json['body']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'info',
      priority: json['priority']?.toString() ?? 'normal',
      requiresAck: json['requiresAck'] == true,
    );
  }
}

class SwapEstimateResult {
  const SwapEstimateResult({this.estimate, this.range, this.rangeError});

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
