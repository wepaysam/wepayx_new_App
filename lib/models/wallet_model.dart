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
    return BalanceRow(
      asset: (json['asset'] as String? ?? '').toUpperCase(),
      network: json['network'] as String? ?? '',
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
    final amount = BalanceRow._toDouble(json['amount']);
    final typeText = (json['type'] as String? ?? '').toLowerCase();
    final direction = amount < 0 ||
            typeText.contains('withdraw') ||
            typeText.contains('split')
        ? 'sent'
        : 'received';

    return ActivityItem(
      id: '${json['id'] ?? json['reference'] ?? ''}',
      type: direction,
      asset: (json['asset'] as String? ?? '').toUpperCase(),
      network: json['network'] as String? ?? '',
      amount: amount.abs(),
      status: json['status'] as String? ?? 'confirmed',
      createdAt: json['created_at'] as String?,
      fee: json['fee']?.toString(),
      netAmount: json['net_amount']?.toString(),
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
    return PendingWithdrawal(
      id: json['id'] as int,
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
        if (value != null) addresses['$key'] = '$value';
      });
    }

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

    return AuthSession(
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      wallet: WalletModel.fromJson(json['wallet'] as Map<String, dynamic>?),
      events: events,
    );
  }
}
