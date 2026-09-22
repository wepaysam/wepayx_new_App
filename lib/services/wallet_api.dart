import '../models/api_models.dart';
import '../models/user_model.dart';
import '../models/wallet_model.dart';
import 'api_client.dart';

class WalletApi {
  WalletApi(this._client);

  final ApiClient _client;

  Future<bool> health() async {
    try {
      final data = await _client.get('/health');
      if (data['ok'] == true) return true;
    } catch (_) {}
    final fallback = await _client.get('/api/health');
    return fallback['ok'] == true;
  }

  Future<Map<String, dynamic>> catalog() async {
    return _client.get('/api/app/v1/catalog');
  }

  Future<AppUpdateInfo> appUpdate() async {
    final data = await _client.get('/api/app/update');
    final raw = data['update'] as Map<String, dynamic>? ?? data;
    return AppUpdateInfo.fromJson(raw);
  }

  Future<AuthSession> me({String? email}) async {
    return AuthSession.fromJson(await meRaw(email: email));
  }

  /// Live NEX: POST /api/users/me or POST /api/me, then GET compatibility paths.
  Future<Map<String, dynamic>> meRaw({String? email}) async {
    final body = _sessionLookupBody(email: email);
    return _firstSuccessful([
      () => _client.post('/api/users/me', body: body),
      () => _client.post('/api/me', body: body),
      () => _client.get('/api/me'),
      () => _client.get('/api/wallet'),
    ]);
  }

  Map<String, dynamic> _sessionLookupBody({String? email}) {
    final token = _client.sessionToken;
    return {
      if (token != null && token.isNotEmpty) 'session_token': token,
      if (email != null && email.isNotEmpty) 'email': email,
    };
  }

  Future<Map<String, dynamic>> _firstSuccessful(
    List<Future<Map<String, dynamic>> Function()> attempts,
  ) async {
    Object? lastError;
    for (final attempt in attempts) {
      try {
        final data = await attempt();
        if (data['ok'] == false) {
          lastError = Exception(_apiError(data, 'Request failed'));
          continue;
        }
        return data;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Request failed');
  }

  /// Sends signup OTP. Account is created only after [confirmSignup].
  /// [telegramId] is only sent when linking an existing Telegram user.
  Future<Map<String, dynamic>> requestSignup({
    String? telegramId,
    required String email,
    required String password,
    String? username,
  }) async {
    final data = await _client.post(
      '/api/auth/signup/request',
      body: {
        if (telegramId != null && telegramId.isNotEmpty)
          'telegram_id': telegramId,
        'email': email,
        'password': password,
        if (username != null && username.isNotEmpty) 'username': username,
      },
    );
    if (data['ok'] == false) {
      throw Exception(_apiError(data, 'Could not send verification code'));
    }
    return data;
  }

  /// Legacy name used by the OTP screen resend path.
  Future<Map<String, dynamic>> requestSignupEmailVerification({
    String? telegramId,
    required String email,
    required String password,
    String? username,
  }) {
    return requestSignup(
      telegramId: telegramId,
      email: email,
      password: password,
      username: username,
    );
  }

  Future<AuthSession> confirmSignup({
    String? telegramId,
    required String email,
    required String password,
    required String otp,
    String? username,
  }) async {
    final data = await _client.post(
      '/api/auth/signup/confirm',
      body: {
        if (telegramId != null && telegramId.isNotEmpty)
          'telegram_id': telegramId,
        'email': email,
        'password': password,
        'otp': otp,
        if (username != null && username.isNotEmpty) 'username': username,
      },
    );
    if (data['ok'] == false) {
      throw Exception(_apiError(data, 'Invalid or expired verification code'));
    }
    await _captureSessionToken(data);
    return _sessionFromAuthResponse(data, email: email, username: username);
  }

  Future<UserModel?> confirmSignupEmailVerification({
    String? telegramId,
    required String email,
    required String password,
    required String otp,
    String? username,
  }) async {
    final session = await confirmSignup(
      telegramId: telegramId,
      email: email,
      password: password,
      otp: otp,
      username: username,
    );
    return session.user;
  }

  /// Verifies credentials and sends a login OTP. Session is created only after
  /// [confirmLoginEmailVerification].
  Future<Map<String, dynamic>> requestLoginOtp({
    required String email,
    required String password,
  }) async {
    final data = await _client.post(
      '/api/auth/login/request',
      body: {'email': email, 'password': password},
    );
    if (data['ok'] == false) {
      throw Exception(_apiError(data, 'Login failed'));
    }
    if (data['user'] != null) {
      await _captureSessionToken(data);
      return {...data, 'loginOtpRequired': data['loginOtpRequired'] == true};
    }
    if (data['loginOtpRequired'] == true || data['ok'] == true) {
      return {...data, 'loginOtpRequired': true};
    }
    throw Exception(_apiError(data, 'Login failed'));
  }

  Future<AuthSession> confirmLoginEmailVerification({
    required String email,
    required String otp,
  }) async {
    final data = await _client.post(
      '/api/auth/login/confirm',
      body: {'email': email, 'otp': otp},
    );
    if (data['ok'] == false) {
      throw Exception(_apiError(data, 'Invalid or expired code'));
    }
    await _captureSessionToken(data);
    final session = _sessionFromAuthResponse(data, email: email);
    if (session.user == null && data['token'] == null && data['access_token'] == null) {
      throw Exception(_apiError(data, 'Invalid or expired code'));
    }
    return session;
  }

  Future<Map<String, dynamic>> checkUser({
    String? telegramId,
    String? email,
    String? userId,
  }) async {
    final body = <String, dynamic>{
      if (email != null && email.isNotEmpty) 'email': email,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
    };
    // Only send a real NEX telegram id. A device-generated numeric id looks
    // up the wrong user (or none) and must not replace the email lookup.
    if (telegramId != null &&
        telegramId.isNotEmpty &&
        (telegramId.startsWith('futre:') ||
            email == null ||
            email.isEmpty)) {
      body['telegram_id'] = telegramId;
    }
    if (body.isEmpty) {
      throw Exception('Email or telegram id is required');
    }
    return _client.post('/api/users/check', body: body);
  }

  Future<void> _captureSessionToken(Map<String, dynamic> data) async {
    final token = _readToken(data);
    if (token != null) {
      await _client.setSessionToken(token);
    }
  }

  String? _readToken(Map<String, dynamic> data) {
    for (final key in ['token', 'access_token', 'session_token', 'bearer']) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    final nested = data['session'];
    if (nested is Map) {
      final value = nested['token'] ?? nested['access_token'];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  AuthSession _sessionFromAuthResponse(
    Map<String, dynamic> data, {
    required String email,
    String? username,
  }) {
    final session = AuthSession.fromJson(data);
    if (session.user != null) {
      return session.user!.emailVerified == true
          ? session
          : AuthSession(
              user: session.user!.copyWith(emailVerified: true),
              wallet: session.wallet,
              events: session.events,
            );
    }
    return AuthSession(
      user: UserModel(
        id: int.tryParse('${data['user_id'] ?? data['id'] ?? 0}') ?? 0,
        email: email,
        name: username,
        emailVerified: true,
        telegramId: data['telegram_id']?.toString(),
      ),
      wallet: session.wallet,
      events: session.events,
    );
  }

  String _apiError(Map<String, dynamic> data, String fallback) {
    return ApiException.describe(
      error: data['error']?.toString(),
      message: data['message']?.toString(),
      fallback: fallback,
    );
  }

  Future<void> requestForgotPassword({required String email}) async {
    try {
      final data = await _client.post(
        '/api/auth/forgot-password/request',
        body: {'email': email},
      );
      if (data['ok'] == false) {
        final code = data['error']?.toString() ?? '';
        // Never reveal whether the email exists.
        if (_hidesAccountExistence(code)) return;
        throw Exception(_apiError(data, 'Could not send reset code'));
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404 || _hidesAccountExistence(e.code ?? e.message)) {
        return;
      }
      rethrow;
    }
  }

  Future<DateTime?> confirmForgotPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final data = await _client.post(
      '/api/auth/forgot-password/confirm',
      body: {
        'email': email,
        'otp': otp.trim(),
        'new_password': newPassword,
        'newPassword': newPassword,
      },
    );
    if (data['ok'] == false) {
      throw Exception(_apiError(data, 'Password reset failed'));
    }
    return _parseTimestamp(data['locked_until'] ?? data['lockedUntil']);
  }

  bool _hidesAccountExistence(String code) {
    final value = code.toLowerCase();
    return value.contains('not_found') ||
        value.contains('unknown') ||
        value.contains('no_account') ||
        value.contains('account_not_found');
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      final ms = value > 2000000000 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  Future<String?> requestAccountDelete({
    required String email,
    required String password,
  }) async {
    final data = await _client.post(
      '/api/account/delete/request',
      body: {'email': email, 'password': password},
    );
    if (data['ok'] == false) {
      throw Exception(_apiError(data, 'Could not send delete code'));
    }
    return data['email']?.toString();
  }

  Future<void> confirmAccountDelete({
    required String email,
    required String password,
    required String otp,
  }) async {
    final data = await _client.post(
      '/api/account/delete/confirm',
      body: {'email': email, 'password': password, 'otp': otp},
    );
    if (data['ok'] == false) {
      throw Exception(_apiError(data, 'Account deletion failed'));
    }
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

  Future<AuthSession> wallet({String? email}) async {
    return liveWalletSession(email: email);
  }

  /// Same as [wallet] but keeps a raw payload for session cache.
  Future<Map<String, dynamic>> walletRaw({String? email}) async {
    return meRaw(email: email);
  }

  Future<AuthSession> liveWalletSession({String? email}) async {
    AuthSession? combined;
    Object? lastError;

    Future<void> absorb(Future<Map<String, dynamic>> Function() load) async {
      try {
        final data = await load();
        if (data['ok'] == false) {
          lastError = Exception(_apiError(data, 'Could not load wallet'));
          return;
        }
        final next = AuthSession.fromJson(data);
        combined = combined == null ? next : combined!.merge(next);
      } catch (e) {
        lastError = e;
      }
    }

    bool isComplete() {
      final session = combined;
      if (session == null) return false;
      return session.user != null &&
          session.wallet.addresses.isNotEmpty &&
          session.wallet.balances.isNotEmpty;
    }

    await absorb(() => _client.get('/api/wallet'));
    if (!isComplete()) {
      await absorb(
        () => _client.post(
          '/api/users/balance',
          body: _sessionLookupBody(email: email),
        ),
      );
    }
    if (!isComplete()) {
      await absorb(() => meRaw(email: email));
    }

    if (combined == null) {
      // Surface the real failure (e.g. an expired session) so callers can tell
      // a logout apart from a network hiccup.
      throw lastError ?? Exception('Could not load wallet');
    }
    return combined!;
  }

  /// Ledger history: deposits, withdrawals, refunds and reconciliations.
  ///
  /// Prefers the session endpoints, then falls back to the developer lookup.
  Future<List<ActivityItem>> ledgerHistory({
    int limit = 50,
    String? email,
  }) async {
    final data = await _firstSuccessful([
      () => _client.get(
        '/api/ledger-history',
        queryParameters: {'limit': '$limit'},
      ),
      () => _client.get('/api/activity', queryParameters: {'limit': '$limit'}),
      () => _client.post(
        '/api/users/ledger',
        body: {..._sessionLookupBody(email: email), 'limit': limit},
      ),
      () => _client.post(
        '/api/users/ledger-history',
        body: {..._sessionLookupBody(email: email), 'limit': limit},
      ),
    ]);

    final rows =
        data['history'] ??
        data['ledger'] ??
        data['activity'] ??
        data['transactions'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(ActivityItem.fromJson)
        .toList();
  }

  Future<Map<String, CryptoPrice>> cryptoPrices() async {
    return (await cryptoPricesRaw()).prices;
  }

  Future<CryptoPricesSnapshot> cryptoPricesRaw() async {
    final data = await _client.get('/api/crypto-prices');
    return CryptoPricesSnapshot.fromJson(data);
  }

  /// `GET /api/fees`. Passing asset/network/amount returns the amount-aware
  /// `selected` row, including per-user percentage overrides.
  Future<Map<String, dynamic>> fees({
    String? asset,
    String? network,
    double? amount,
  }) async {
    return _client.get(
      '/api/fees',
      queryParameters: {
        if (asset != null && asset.isNotEmpty) 'asset': asset,
        if (network != null && network.isNotEmpty) 'network': network,
        if (amount != null && amount > 0) 'amount': amount.toString(),
      },
    );
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

  /// Sends a Telegram-style popup via `POST /api/notifications/popup`.
  ///
  /// Do not pass [force] from normal app flows — that flag is for
  /// backend/admin compliance warnings only.
  Future<NotificationPopupResult> sendNotificationPopup({
    required String title,
    required String message,
    bool force = false,
    String? telegramId,
    String? email,
    String? userId,
  }) async {
    try {
      final data = await _client.post(
        '/api/notifications/popup',
        body: {
          'title': title,
          'message': message,
          if (force) 'force': true,
          if (telegramId != null && telegramId.isNotEmpty)
            'telegram_id': telegramId,
          if (email != null && email.isNotEmpty) 'email': email,
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
        },
      );
      return NotificationPopupResult.fromJson(data);
    } on ApiException catch (error) {
      if (error.code == 'user_restricted_or_blocked') {
        return NotificationPopupResult(
          ok: false,
          error: 'user_restricted_or_blocked',
          blocked: true,
        );
      }
      rethrow;
    }
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

  Future<AccountStatusInfo> accountStatus({
    String? email,
    String? telegramId,
  }) async {
    final check = await checkUser(
      email: email,
      telegramId: telegramId,
    );
    final raw = check['user'];
    if (raw is Map) {
      return AccountStatusInfo.fromUserCheck(Map<String, dynamic>.from(raw));
    }
    if (check.containsKey('restricted') ||
        check.containsKey('can_withdraw') ||
        check['ok'] == true) {
      return AccountStatusInfo.fromUserCheck(Map<String, dynamic>.from(check));
    }
    throw Exception('Invalid users/check response');
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
        'addressTo': ?addressTo,
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
      body: {'action': action, 'detail': ?detail},
    );
    return (data['events'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(WalletEvent.fromJson)
        .toList();
  }
}
