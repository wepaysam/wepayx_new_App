import '../core/constants/assets.dart';
import 'user_model.dart';

class BalanceRow {
  const BalanceRow({
    required this.asset,
    required this.network,
    required this.balance,
    this.updatedAt,
  });

  final String asset;
  final String network;
  final double balance;
  final String? updatedAt;

  factory BalanceRow.fromJson(Map<String, dynamic> json) {
    final mapped = appAssetFromLedger(
      json['asset'] as String? ?? '',
      network: json['network'] as String?,
    );
    return BalanceRow(
      asset: mapped.asset,
      network: mapped.network,
      balance: _toDouble(json['balance']),
      updatedAt: json['updated_at'] as String?,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}

class WalletEvent {
  const WalletEvent({
    required this.action,
    this.detail,
    this.createdAt,
  });

  final String action;
  final String? detail;
  final String? createdAt;

  factory WalletEvent.fromJson(Map<String, dynamic> json) {
    return WalletEvent(
      action: json['action'] as String? ?? '',
      detail: json['detail'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.type,
    required this.asset,
    required this.network,
    required this.amount,
    required this.status,
    this.createdAt,
    this.fee,
    this.netAmount,
    this.toAddress,
    this.fromAddress,
    this.txid,
    this.reference,
    this.error,
  });

  final String id;
  final String type;
  final String asset;
  final String network;
  final double amount;
  final String status;
  final String? createdAt;
  final String? fee;
  final String? netAmount;
  final String? toAddress;
  final String? fromAddress;
  final String? txid;
  final String? reference;
  final String? error;

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    final amount = BalanceRow._toDouble(json['signedAmount'] ?? json['amount']);
    final typeText = (json['type'] as String? ?? '').toLowerCase();

    // Ledger rows state the direction outright; older payloads only imply it.
    final rawDirection = (json['direction'] as String? ?? '').toLowerCase();
    final String direction;
    if (rawDirection == 'debit' || rawDirection == 'sent') {
      direction = 'sent';
    } else if (rawDirection == 'credit' || rawDirection == 'received') {
      direction = 'received';
    } else if (typeText.contains('swap')) {
      direction = 'swapped';
    } else {
      direction =
          amount < 0 ||
              typeText.contains('withdraw') ||
              typeText.contains('split')
          ? 'sent'
          : 'received';
    }

    final mapped = appAssetFromLedger(
      (json['asset'] ?? json['assetKey']) as String? ?? '',
      network: json['network'] as String?,
    );
    return ActivityItem(
      id: '${json['id'] ?? json['reference'] ?? ''}',
      type: direction,
      asset: mapped.asset,
      network: mapped.network,
      amount: amount.abs(),
      status: json['status'] as String? ?? 'confirmed',
      createdAt: json['created_at'] as String?,
      fee: (json['fee'] ?? json['networkFee'])?.toString(),
      netAmount:
          (json['netAmount'] ?? json['net_amount'] ?? json['receiverGets'])
              ?.toString(),
      toAddress: json['to_address'] as String?,
      fromAddress: (json['from_address'] ?? json['from']) as String?,
      txid: (json['txid'] ?? json['reference'])?.toString(),
      reference: json['reference']?.toString(),
      error: json['error'] as String?,
    );
  }
}

class PendingWithdrawal {
  const PendingWithdrawal({
    required this.id,
    required this.status,
    required this.asset,
    required this.network,
    required this.amount,
  });

  final int id;
  final String status;
  final String asset;
  final String network;
  final String amount;

  factory PendingWithdrawal.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return PendingWithdrawal(
      id: rawId is int ? rawId : int.tryParse('$rawId') ?? 0,
      status: json['status'] as String? ?? 'processing',
      asset: json['asset'] as String? ?? '',
      network: json['network'] as String? ?? '',
      amount: json['amount']?.toString() ?? '0',
    );
  }
}

class WalletModel {
  const WalletModel({
    this.addresses = const {},
    this.balances = const [],
    this.activity = const [],
    this.pendingWithdrawal,
  });

  final Map<String, String> addresses;
  final List<BalanceRow> balances;
  final List<ActivityItem> activity;
  final PendingWithdrawal? pendingWithdrawal;

  factory WalletModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WalletModel();

    final rawAddresses = json['addresses'];
    final addresses = <String, String>{};
    if (rawAddresses is Map) {
      rawAddresses.forEach((key, value) {
        if (value != null && '$value'.isNotEmpty) addresses['$key'] = '$value';
      });
    }
    void putAddress(String key, dynamic value) {
      if (value == null) return;
      final text = '$value';
      if (text.isEmpty) return;
      addresses.putIfAbsent(key, () => text);
    }

    putAddress('BTC', json['btc_address']);
    putAddress('ETH', json['evm_address']);
    putAddress('BNB', json['evm_address']);
    putAddress('TRX', json['tron_address']);
    putAddress('USDT_TRC20', json['tron_address']);
    putAddress('USDT_BEP20', json['evm_address']);
    putAddress('USDT_ERC20', json['evm_address']);
    putAddress('USDC_ERC20', json['evm_address']);

    final balances = (json['balances'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(BalanceRow.fromJson)
        .toList();

    final activity = (json['activity'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ActivityItem.fromJson)
        .toList();

    PendingWithdrawal? pending;
    final pendingJson = json['pendingWithdrawal'];
    if (pendingJson is Map<String, dynamic>) {
      pending = PendingWithdrawal.fromJson(pendingJson);
    }

    return WalletModel(
      addresses: addresses,
      balances: balances,
      activity: activity,
      pendingWithdrawal: pending,
    );
  }

  WalletModel merge(WalletModel other) {
    final selfSum = balances.fold<double>(0, (sum, row) => sum + row.balance);
    final otherSum = other.balances.fold<double>(
      0,
      (sum, row) => sum + row.balance,
    );
    return WalletModel(
      addresses: addresses.isNotEmpty ? addresses : other.addresses,
      balances: otherSum > selfSum
          ? other.balances
          : (balances.isNotEmpty ? balances : other.balances),
      activity: activity.isNotEmpty ? activity : other.activity,
      pendingWithdrawal: pendingWithdrawal ?? other.pendingWithdrawal,
    );
  }
}

class AuthSession {
  const AuthSession({
    this.user,
    this.wallet = const WalletModel(),
    this.events = const [],
  });

  final UserModel? user;
  final WalletModel wallet;
  final List<WalletEvent> events;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final events = (json['events'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(WalletEvent.fromJson)
        .toList();

    final userJson = json['user'];
    final userMap = userJson is Map<String, dynamic> ? userJson : null;
    final nestedWallet = userMap?['wallet'];
    final topWallet = json['wallet'];
    final walletMap = <String, dynamic>{
      if (nestedWallet is Map<String, dynamic>) ...nestedWallet,
      if (topWallet is Map<String, dynamic>) ...topWallet,
    };
    final nestedBalances = userMap?['balances'];
    final topBalances = json['balances'];
    if (topBalances is List) {
      walletMap['balances'] = topBalances;
    } else if (nestedBalances is List && walletMap['balances'] == null) {
      walletMap['balances'] = nestedBalances;
    }

    return AuthSession(
      user: userMap != null ? UserModel.fromJson(userMap) : null,
      wallet: WalletModel.fromJson(walletMap.isEmpty ? null : walletMap),
      events: events,
    );
  }

  AuthSession merge(AuthSession other) {
    return AuthSession(
      user: user ?? other.user,
      wallet: wallet.merge(other.wallet),
      events: events.isNotEmpty ? events : other.events,
    );
  }
}
