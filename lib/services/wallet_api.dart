import '../models/api_models.dart';
import '../models/user_model.dart';
import '../models/wallet_model.dart';
import 'api_client.dart';

class WalletApi {
  WalletApi(this._client);

  final ApiClient _client;

  Future<bool> health() async {
    final data = await _client.get('/api/health');
    return data['ok'] == true;
  }

  Future<Map<String, dynamic>> catalog() async {
    return _client.get('/api/app/v1/catalog');
  }

  Future<AppUpdateInfo> appUpdate() async {
    final data = await _client.get('/api/app/update');
    final raw = data['update'] as Map<String, dynamic>? ?? data;
    return AppUpdateInfo.fromJson(raw);
  }

  Future<AuthSession> me() async {
    final data = await _client.get('/api/me');
    return AuthSession.fromJson(data);
  }

  Future<AuthSession> signup({
    required String email,
    required String password,
    String? name,
  }) async {
    final data = await _client.post(
      '/api/signup',
      body: {
        'email': email,
        'password': password,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
    return AuthSession.fromJson(data);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.post(
      '/api/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(data);
  }

  Future<void> logout() async {
    await _client.post('/api/logout', body: {});
  }

  Future<UserModel> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final data = await _client.post(
      '/api/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    if (data['ok'] != true) {
      throw Exception(data['error']?.toString() ?? 'Password change failed');
    }
    final userJson = data['user'];
    if (userJson is! Map<String, dynamic>) {
      throw Exception('Password change failed');
    }
    return UserModel.fromJson(userJson);
  }

  Future<AuthSession> wallet() async {
    final data = await _client.get('/api/wallet');
    return AuthSession.fromJson(data);
  }

  Future<Map<String, CryptoPrice>> cryptoPrices() async {
    return (await cryptoPricesRaw()).prices;
  }

  Future<CryptoPricesSnapshot> cryptoPricesRaw() async {
    final data = await _client.get('/api/crypto-prices');
    return CryptoPricesSnapshot.fromJson(data);
  }

  Future<Map<String, dynamic>> fees() async {
    return _client.get('/api/fees');
  }

  Future<DepositAddressResult> depositAddress({
    required String asset,
    required String network,
  }) async {
    final data = await _client.post(
      '/api/deposit-address',
      body: {'asset': asset, 'network': network},
    );
    return DepositAddressResult.fromJson(data);
  }

  Future<List<BalanceRow>> balances() async {
    final data = await _client.get('/api/balances');
    return (data['balances'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(BalanceRow.fromJson)
        .toList();
  }

  Future<BalanceRow?> liveTrxBalance() async {
    final data = await _client.get('/api/live-trx-balance');
    final balance = data['balance'];
    if (balance is Map<String, dynamic>) {
      return BalanceRow.fromJson(balance);
    }
    return null;
  }

  Future<List<PopupNotification>> popupNotifications({
    bool consume = true,
  }) async {
    final data = await _client.get(
      '/api/popup-notifications',
      queryParameters: consume ? {'consume': '1'} : null,
    );
    return (data['notifications'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PopupNotification.fromJson)
        .toList();
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await _client.post(
      '/api/device-token',
      body: {'token': token, 'platform': platform},
    );
  }

  Future<AccountStatusInfo> accountStatus() async {
    final data = await _client.get('/api/account-status');
    final raw = data['accountStatus'];
    if (raw is! Map<String, dynamic>) {
      throw Exception('Invalid account status response');
    }
    return AccountStatusInfo.fromJson(raw);
  }

  Future<SupportTicket> createSupportTicket({
    required String category,
    required String subject,
    required String message,
    String? blockedAction,
  }) async {
    final data = await _client.post(
      '/api/support/tickets',
      body: {
        'category': category,
        'subject': subject,
        'message': message,
        if (blockedAction != null && blockedAction.isNotEmpty)
          'blockedAction': blockedAction,
      },
    );
    final raw = data['ticket'];
    if (raw is! Map<String, dynamic>) {
      throw Exception('Invalid support ticket response');
    }
    return SupportTicket.fromJson(raw);
  }

  Future<List<AppAnnouncement>> announcements({int limit = 3}) async {
    final data = await _client.get(
      '/api/announcements',
      queryParameters: {'limit': limit},
    );
    return (data['announcements'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AppAnnouncement.fromJson)
        .toList();
  }

  Future<WithdrawalResult> withdrawalRequest({
    required String asset,
    required String network,
    required String amount,
    required String toAddress,
  }) async {
    final data = await _client.post(
      '/api/withdrawal-request',
      body: {
        'asset': asset,
        'network': network,
        'amount': amount,
        'toAddress': toAddress,
      },
      receiveTimeout: const Duration(minutes: 3),
      sendTimeout: const Duration(seconds: 60),
    );
    final payload = data['withdrawal'] is Map<String, dynamic>
        ? data['withdrawal'] as Map<String, dynamic>
        : data['request'] is Map<String, dynamic>
        ? data['request'] as Map<String, dynamic>
        : data;
    return WithdrawalResult.fromJson(payload);
  }

  Future<SwapEstimateResult> swapEstimate({
    required String fromAsset,
    required String fromNetwork,
    required String toAsset,
    required String toNetwork,
    required String amount,
    bool fixed = false,
    bool reverse = false,
  }) async {
    final data = await _client.post(
      '/api/swap-estimate',
      body: {
        'fromAsset': fromAsset,
        'fromNetwork': fromNetwork,
        'toAsset': toAsset,
        'toNetwork': toNetwork,
        'amount': amount,
        'fixed': fixed,
        'reverse': reverse,
      },
    );
    return SwapEstimateResult.fromJson(data);
  }

  Future<Map<String, dynamic>> swapExchange({
    required String fromAsset,
    required String fromNetwork,
    required String toAsset,
    required String toNetwork,
    required String amount,
    String? addressTo,
    bool fixed = false,
    bool reverse = false,
  }) async {
    return _client.post(
      '/api/swap-exchange',
      body: {
        'fromAsset': fromAsset,
        'fromNetwork': fromNetwork,
        'toAsset': toAsset,
        'toNetwork': toNetwork,
        'amount': amount,
        if (addressTo != null) 'addressTo': addressTo,
        'fixed': fixed,
        'reverse': reverse,
      },
    );
  }

  Future<List<WalletEvent>> recordAction({
    required String action,
    String? detail,
  }) async {
    final data = await _client.post(
      '/api/action',
      body: {'action': action, if (detail != null) 'detail': detail},
    );
    return (data['events'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(WalletEvent.fromJson)
        .toList();
  }
}
