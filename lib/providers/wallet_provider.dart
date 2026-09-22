import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/otp_bypass.dart';
import '../core/constants/assets.dart';
import '../core/constants/features.dart';
import '../models/api_models.dart';
import '../models/user_model.dart';
import '../models/wallet_model.dart';
import '../services/api_client.dart';
import '../services/push_service.dart';
import '../services/wallet_api.dart';
import '../services/api_endpoint_resolver.dart';
import '../services/coinbase_price_service.dart';
import '../services/notification_delivery.dart';
import '../services/security_service.dart';
import '../services/session_cache.dart';
import '../services/telegram_id_store.dart';

class AssetBalanceView {
  AssetBalanceView({
    required this.definition,
    required this.amount,
    required this.price,
    required this.change24h,
  });

  final AssetDefinition definition;
  double amount;
  double price;
  double? change24h;

  double get usd => amount * price;
}

class WalletProvider extends ChangeNotifier {
  WalletProvider() : _api = WalletApi(ApiClient.instance);

  final WalletApi _api;

  UserModel? user;
  WalletModel wallet = const WalletModel();
  List<WalletEvent> events = [];
  Map<String, CryptoPrice> prices = {};
  String? pricesUpdatedAt;
  String? pricesSource;
  bool pricesStale = false;
  FearGreedIndex? fearGreed;
  Map<String, dynamic>? feesPayload;
  Map<String, WithdrawalFeeInfo> feesByAssetKey = {};
  PopupNotification? activePopup;
  AccountStatusInfo? accountStatus;
  List<AppAnnouncement> announcements = [];
  bool accountFeaturesLoading = false;
  Future<void>? _walletRefresh;
  bool balanceVisible = true;
  bool isDark = true;
  bool loading = false;
  bool initialized = false;
  String? error;

  /// Set after signup until the email OTP is confirmed.
  bool pendingEmailVerification = false;
  final Set<int> _locallyVerifiedUserIds = {};

  /// Login OTP challenge — cleared after successful confirm or logout.
  String? pendingLoginEmail;
  String? _pendingLoginPassword;

  /// Signup OTP challenge — account is created only after confirm.
  String? pendingSignupEmail;
  String? _pendingSignupPassword;
  String? _pendingSignupName;
  bool signupOtpSent = false;

  String? get verificationEmail => pendingSignupEmail ?? user?.email;

  /// True when the signed-in user still needs the email OTP step.
  bool get needsEmailVerification {
    if (pendingSignupEmail != null) return true;
    final current = user;
    if (current == null) return false;
    if (OtpBypass.isExempt(current.email)) return false;
    if (isEmailVerified) return false;
    if (pendingEmailVerification) return true;
    // Backend explicitly marked unverified.
    return current.emailVerified == false;
  }

  bool get isEmailVerified {
    final current = user;
    if (current == null) return false;
    if (OtpBypass.isExempt(current.email)) return true;
    if (current.emailVerified == true) return true;
    if (_locallyVerifiedUserIds.contains(current.id)) return true;
    return false;
  }

  List<AssetBalanceView> get assetViews {
    final totals = <String, double>{};
    for (final row in wallet.balances) {
      totals[row.asset] = (totals[row.asset] ?? 0) + row.balance;
    }

    return kSupportedAssets.map((definition) {
      final live = prices[definition.symbol];
      return AssetBalanceView(
        definition: definition,
        amount: totals[definition.symbol] ?? 0,
        price: live?.price ?? definition.defaultPrice,
        change24h: live?.change24h,
      );
    }).toList();
  }

  double get totalUsd => assetViews.fold(0, (sum, item) => sum + item.usd);

  List<ActivityItem> get activity => wallet.activity;

  PendingWithdrawal? get pendingWithdrawal => wallet.pendingWithdrawal;

  Future<void> bootstrap() async {
    if (initialized) return;
    loading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString('futre_api_key');
      final bakedIn = ApiConfig.apiKey;
      if (bakedIn != null && bakedIn.isNotEmpty) {
        await prefs.setString('futre_api_key', bakedIn);
      } else if (savedKey != null && savedKey.isNotEmpty) {
        ApiConfig.setApiKey(savedKey);
      }
      isDark = prefs.getBool('dark_theme') ?? true;

      // Paint the last known session from disk so a cold start goes straight to
      // the wallet. The live refresh below replaces it as soon as it lands.
      if (await _hydrateCachedSession()) {
        loading = false;
        initialized = true;
        notifyListeners();
        unawaited(_connectAndRestoreSessionSafely(prefs));
        return;
      }

      await _connectAndRestoreSession(prefs);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> _connectAndRestoreSession(SharedPreferences prefs) async {
    await ApiEndpointResolver.resolveAndPersist(prefs);
    await ApiClient.instance.init();
    await restoreSession();
  }

  /// Background variant used when cached data is already on screen — failures
  /// must not escape, the cached view simply stays until the next refresh.
  Future<void> _connectAndRestoreSessionSafely(SharedPreferences prefs) async {
    try {
      await _connectAndRestoreSession(prefs);
    } catch (e) {
      debugPrint('WalletProvider: background session restore failed: $e');
    }
  }

  /// Loads the cached session snapshot. Returns false when there is nothing
  /// usable to show, in which case the normal online path runs.
  Future<bool> _hydrateCachedSession() async {
    final cached = await SessionCache.read();
    if (cached == null) return false;
    try {
      final session = AuthSession.fromJson(cached);
      if (session.user == null) return false;
      user = session.user;
      wallet = session.wallet;
      events = session.events;
      await _applyRestoredUserFlags();
      await _hydrateCachedPrices();
      return true;
    } catch (e) {
      debugPrint('WalletProvider: cached session unusable: $e');
      return false;
    }
  }

  /// Uses the last known prices so cached balances are not valued with the
  /// hardcoded asset defaults before the live prices arrive.
  Future<void> _hydrateCachedPrices() async {
    final cached = await SessionCache.readPrices();
    if (cached == null) return;
    try {
      final snapshot = CryptoPricesSnapshot.fromJson(cached);
      if (snapshot.prices.isEmpty) return;
      prices = snapshot.prices;
      pricesUpdatedAt = snapshot.updatedAt;
      pricesSource = snapshot.source;
      pricesStale = snapshot.stale;
    } catch (e) {
      debugPrint('WalletProvider: cached prices unusable: $e');
    }
  }

  /// Restores the logged-in user from the persisted session cookie.
  Future<bool> restoreSession() async {
    try {
      await ApiClient.instance.init();
      final session = await _api.liveWalletSession();
      user = session.user;
      wallet = session.wallet;
      events = session.events;
      if (user != null) {
        await _applyRestoredUserFlags();
        try {
          await SessionCache.save(await _api.meRaw(email: user?.email));
        } catch (_) {}
      } else {
        await SessionCache.clear();
      }
      notifyListeners();
      unawaited(
        Future.wait([
          _refreshPrices(),
          _refreshFees(),
          refreshAccountFeatures(),
        ]).catchError((_) => <void>[]),
      );
      return user != null;
    } catch (e) {
      error = e.toString();

      // Only the server may end a session. Timeouts, DNS failures, 5xx and
      // unreadable cookie files are transient, so the saved login is kept —
      // otherwise a moment of bad connectivity signs the user out for good.
      if (!ApiClient.isSessionExpiredError(e)) {
        debugPrint('WalletProvider: session restore deferred (transient): $e');
        notifyListeners();
        return user != null;
      }

      // Stale/invalid token: clear it so we don't keep trying to use a guest
      // session (Receive/Deposit may otherwise show blank QR/address).
      await _endExpiredSession();
      return false;
    }
  }

  /// Drops a session the server has rejected, so the app asks for a fresh
  /// login instead of showing a signed-in shell with no wallet data.
  Future<void> _endExpiredSession() async {
    await ApiClient.instance.clearCookies();
    await SessionCache.clear();
    user = null;
    wallet = const WalletModel();
    events = [];
    accountStatus = null;
    announcements = [];
    pendingEmailVerification = false;
    _clearPendingLogin();
    _clearPendingSignup();
    notifyListeners();
  }

  /// Normalises email-verification state for a session restored from the API
  /// or from the cached snapshot.
  Future<void> _applyRestoredUserFlags() async {
    if (user == null) return;
    await _restoreLocalEmailVerification(user!.id);
    if (OtpBypass.isExempt(user!.email)) {
      pendingEmailVerification = false;
      user = user!.copyWith(emailVerified: true);
    } else if (user!.emailVerified == false) {
      // If backend says unverified, keep forcing the OTP step.
      pendingEmailVerification = true;
    }
  }

  Future<void> setApiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', url);
    await ApiClient.instance.updateBaseUrl(url);
    notifyListeners();
  }

  Future<void> setApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    ApiConfig.setApiKey(key);
    if (key == null || key.isEmpty) {
      await prefs.remove('futre_api_key');
    } else {
      await prefs.setString('futre_api_key', key);
    }
    notifyListeners();
  }

  Future<T> _withApiRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      if (!isApiUnreachableError(e)) rethrow;
      final prefs = await SharedPreferences.getInstance();
      final previous = ApiConfig.baseUrl;
      final resolved = await ApiEndpointResolver.resolveAndPersist(prefs);
      if (resolved == null) rethrow;
      if (resolved != previous) {
        await ApiClient.instance.updateBaseUrl(resolved);
      } else {
        await ApiClient.instance.init();
      }
      return await action();
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    String? name,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _withApiRetry(
        () => _signupOnce(email: email, password: password, name: name),
      );
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _signupOnce({
    required String email,
    required String password,
    String? name,
  }) async {
    await _api.requestSignup(
      email: email.trim(),
      password: password,
      username: name,
    );
    pendingSignupEmail = email.trim();
    _pendingSignupPassword = password;
    _pendingSignupName = name;
    signupOtpSent = true;
    pendingEmailVerification = true;
    user = null;
  }

  Future<void> requestSignupEmailVerification() async {
    final email = pendingSignupEmail ?? user?.email;
    final password = _pendingSignupPassword;
    if (email == null || email.isEmpty || password == null) {
      throw Exception('Start signup again to request a new code');
    }
    await _withApiRetry(
      () => _api.requestSignup(
        email: email,
        password: password,
        username: _pendingSignupName,
      ),
    );
    signupOtpSent = true;
  }

  Future<void> confirmSignupEmailVerification(String otp) async {
    final email = pendingSignupEmail ?? user?.email;
    final password = _pendingSignupPassword;
    if (email == null || email.isEmpty || password == null) {
      throw Exception('Start signup again to verify your code');
    }
    final code = otp.trim();
    if (code.length < 4) {
      throw Exception('Enter the verification code from your email');
    }

    final session = await _withApiRetry(
      () => _api.confirmSignup(
        email: email,
        password: password,
        otp: code,
        username: _pendingSignupName,
      ),
    );

    _applySession(session);
    if (user != null) {
      user = user!.copyWith(emailVerified: true);
    }
    pendingEmailVerification = false;
    _clearPendingSignup();
    await _afterAuthSessionApplied();
    final id = user?.id;
    if (id != null) {
      _locallyVerifiedUserIds.add(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('email_verified_$id', true);
    }
    notifyListeners();
  }

  Future<void> _restoreLocalEmailVerification(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('email_verified_$userId') == true) {
      _locallyVerifiedUserIds.add(userId);
    }
  }

  Future<void> requestLoginOtp({
    required String email,
    required String password,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _withApiRetry(
        () => _requestLoginOtpOnce(email: email, password: password),
      );
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _requestLoginOtpOnce({
    required String email,
    required String password,
  }) async {
    final data = await _api.requestLoginOtp(email: email, password: password);

    // Prefer an immediate session when the server returns one.
    if (data['user'] != null) {
      _applySession(AuthSession.fromJson(data));
      await _afterAuthSessionApplied();
      _clearPendingLogin();
      unawaited(refreshWallet());
      return;
    }

    final otpRequired = data['loginOtpRequired'] == true;
    if (otpRequired || data['ok'] == true || data['message'] == 'login_otp_sent') {
      pendingLoginEmail = email.trim();
      _pendingLoginPassword = password;
      return;
    }

    throw Exception(data['error']?.toString() ?? 'Login failed');
  }

  Future<void> resendLoginOtp() async {
    final email = pendingLoginEmail;
    final password = _pendingLoginPassword;
    if (email == null || password == null) {
      throw Exception('Start login again to request a new code');
    }
    await _withApiRetry(
      () => _api.requestLoginOtp(email: email, password: password),
    );
  }

  Future<void> confirmLoginOtp(String otp) async {
    final email = pendingLoginEmail;
    if (email == null || email.isEmpty) {
      throw Exception('Start login again to verify your code');
    }
    final code = otp.trim();
    if (code.length < 4) {
      throw Exception('Enter the verification code from your email');
    }

    loading = true;
    error = null;
    notifyListeners();
    try {
      final session = await _withApiRetry(
        () => _api.confirmLoginEmailVerification(email: email, otp: code),
      );
      _applySession(session);
      await _afterAuthSessionApplied();
      _clearPendingLogin();
      unawaited(refreshWallet());
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _afterAuthSessionApplied() async {
    if (user != null) {
      await _restoreLocalEmailVerification(user!.id);
      if (OtpBypass.isExempt(user!.email)) {
        pendingEmailVerification = false;
        user = user!.copyWith(emailVerified: true);
        return;
      }
      if (user!.emailVerified == false && !isEmailVerified) {
        pendingEmailVerification = true;
      }
    }
  }

  void _clearPendingLogin() {
    pendingLoginEmail = null;
    _pendingLoginPassword = null;
  }

  void _clearPendingSignup() {
    pendingSignupEmail = null;
    _pendingSignupPassword = null;
    _pendingSignupName = null;
    signupOtpSent = false;
  }

  Future<void> requestForgotPassword(String email) async {
    await _withApiRetry(() => _api.requestForgotPassword(email: email.trim()));
  }

  Future<void> confirmForgotPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final lockedUntil = await _withApiRetry(
      () => _api.confirmForgotPassword(
        email: email.trim(),
        otp: otp.trim(),
        newPassword: newPassword,
      ),
    );
    if (lockedUntil != null) {
      accountStatus = (accountStatus ??
              const AccountStatusInfo(
                status: 'active',
                isRestricted: false,
                isFrozen: false,
                message: '',
                blockedFeatures: {
                  'withdrawal': true,
                  'swap': true,
                },
                affectedFeatures: ['withdrawal', 'swap'],
                supportRequired: false,
              ))
          .withLockedUntil(lockedUntil);
    }
  }

  Future<String?> requestAccountDelete({required String password}) async {
    final email = user?.email;
    if (email == null || email.isEmpty) {
      throw Exception('No account email available');
    }
    return _withApiRetry(
      () => _api.requestAccountDelete(email: email, password: password),
    );
  }

  Future<void> confirmAccountDelete({
    required String password,
    required String otp,
  }) async {
    final email = user?.email;
    if (email == null || email.isEmpty) {
      throw Exception('No account email available');
    }
    await _withApiRetry(
      () => _api.confirmAccountDelete(
        email: email,
        password: password,
        otp: otp.trim(),
      ),
    );
    await TelegramIdStore.rotate();
    try {
      await _api.logout();
    } catch (_) {}
    await ApiClient.instance.clearCookies();
    await SessionCache.clear();
    user = null;
    wallet = const WalletModel();
    events = [];
    accountStatus = null;
    announcements = [];
    pendingEmailVerification = false;
    _clearPendingLogin();
    _clearPendingSignup();
    await clearLastNotificationId();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    await ApiClient.instance.clearCookies();
    await SessionCache.clear();
    user = null;
    wallet = const WalletModel();
    events = [];
    accountStatus = null;
    announcements = [];
    pendingEmailVerification = false;
    _clearPendingLogin();
    _clearPendingSignup();
    await clearLastNotificationId();
    notifyListeners();
  }

  bool isFeatureBlocked(String feature) {
    if (feature == 'swap' && !kSwapEnabled) return true;
    if (needsEmailVerification) {
      if (feature == 'deposit' ||
          feature == 'withdrawal' ||
          feature == 'swap') {
        return true;
      }
    }
    final status = accountStatus;
    if (status == null) return false;
    if (status.hasRestrictions) return true;
    if ((feature == 'withdrawal' || feature == 'swap') && !status.canWithdraw) {
      return true;
    }
    return status.securityLocks.any(
      (lock) => lock.isActive && lock.matchesFeature(feature),
    );
  }

  Future<void> refreshAccountFeatures({bool force = false}) async {
    if (user == null) return;
    if (accountFeaturesLoading && !force) return;
    accountFeaturesLoading = true;
    try {
      try {
        accountStatus = await _api.accountStatus(
          email: user?.email,
          telegramId: user?.telegramId,
        );
        final nexTelegramId = accountStatus?.telegramId;
        if (nexTelegramId != null &&
            nexTelegramId.isNotEmpty &&
            user != null &&
            user!.telegramId != nexTelegramId) {
          user = user!.copyWith(telegramId: nexTelegramId);
        }
        debugPrint(
          'WalletProvider: users/check restricted=${accountStatus?.isRestricted} '
          'blocked=${accountStatus?.isRestricted} frozen=${accountStatus?.isFrozen} '
          'can_withdraw=${accountStatus?.canWithdraw} '
          'locks=${accountStatus?.securityLocks.length} '
          'hasRestrictions=${accountStatus?.hasRestrictions} '
          'hasSecurityHold=${accountStatus?.hasSecurityHold} '
          'emailGate=$needsEmailVerification '
          'sendBlocked=${isFeatureBlocked('withdrawal')} '
          'swapBlocked=${isFeatureBlocked('swap')}',
        );
      } catch (e) {
        debugPrint('WalletProvider: account status refresh failed: $e');
      }
      try {
        announcements = await _api.announcements(limit: 3);
      } catch (e) {
        debugPrint('WalletProvider: announcements refresh failed: $e');
      }
      notifyListeners();
    } finally {
      accountFeaturesLoading = false;
    }
  }

  Future<SupportTicket> createSupportTicket({
    required String category,
    required String subject,
    required String message,
    String? blockedAction,
  }) {
    return _api.createSupportTicket(
      category: category,
      subject: subject,
      message: message,
      blockedAction: blockedAction,
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final updated = await _withApiRetry(
        () => _api.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      );
      user = updated;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshWallet() async {
    if (user == null) return;
    // Several screens and the poller can ask at once; one flight is enough.
    final inFlight = _walletRefresh;
    if (inFlight != null) return inFlight;
    final refresh = _refreshWalletOnce();
    _walletRefresh = refresh;
    try {
      await refresh;
    } finally {
      _walletRefresh = null;
    }
  }

  Future<void> _refreshWalletOnce() async {
    try {
      final results = await Future.wait([
        _api.liveWalletSession(email: user?.email),
        _api
            .ledgerHistory(email: user?.email)
            .catchError((Object e) {
              debugPrint('WalletProvider: ledger history failed: $e');
              return const <ActivityItem>[];
            }),
      ]);
      final session = results[0] as AuthSession;
      final history = results[1] as List<ActivityItem>;

      user = session.user ?? user;
      wallet = WalletModel(
        addresses: session.wallet.addresses,
        balances: session.wallet.balances,
        // Ledger history is the authoritative record; the wallet payload's
        // activity is only a fallback when the ledger call fails.
        activity: history.isNotEmpty ? history : session.wallet.activity,
        pendingWithdrawal: session.wallet.pendingWithdrawal,
      );
      events = session.events;
      debugPrint(
        'WalletProvider: applied wallet balances=${wallet.balances.length} '
        'total=${wallet.balances.fold<double>(0, (sum, row) => sum + row.balance)} '
        'addresses=${wallet.addresses.length} '
        'history=${wallet.activity.length}',
      );
      notifyListeners();
      await SessionCache.save({
        'user': _cachedUserPayload(),
        'wallet': {
          'addresses': wallet.addresses,
          'balances': [
            for (final row in wallet.balances)
              {
                'asset': row.asset,
                'network': row.network,
                'balance': row.balance,
              },
          ],
          'activity': [
            for (final item in wallet.activity)
              {
                'id': item.id,
                'direction': item.type,
                'asset': item.asset,
                'network': item.network,
                'amount': item.amount,
                'status': item.status,
                'created_at': ?item.createdAt,
                'fee': ?item.fee,
                'netAmount': ?item.netAmount,
                'to_address': ?item.toAddress,
                'txid': ?item.txid,
                'reference': ?item.reference,
              },
          ],
        },
        'events': [
          for (final event in events)
            {
              'action': event.action,
              'detail': event.detail,
              'created_at': event.createdAt,
            },
        ],
      });
    } catch (e) {
      debugPrint('WalletProvider: refreshWallet failed: $e');
      if (ApiClient.isSessionExpiredError(e)) {
        debugPrint('WalletProvider: session rejected by server, signing out');
        await _endExpiredSession();
      }
    }
  }

  Map<String, dynamic>? _cachedUserPayload() {
    final current = user;
    if (current == null) return null;
    return {
      'id': current.id,
      'email': current.email,
      'name': current.name,
      'created_at': current.createdAt,
      if (current.emailVerified != null) 'emailVerified': current.emailVerified,
      if (current.emailVerifiedAt != null)
        'emailVerifiedAt': current.emailVerifiedAt,
      if (current.telegramId != null) 'telegram_id': current.telegramId,
    };
  }

  Future<void> _refreshPrices() async {
    CryptoPricesSnapshot? snapshot;

    try {
      snapshot = await _api.cryptoPricesRaw();
      if (isUsableBackendPrices(snapshot)) {
        debugPrint(
          'WalletProvider: live rates ok source=${snapshot.source} '
          'symbols=${snapshot.prices.keys.length} stale=${snapshot.stale}',
        );
        _applyPriceSnapshot(await _withMarketFallback(snapshot));
        await _refreshFearGreed();
        return;
      }
      debugPrint(
        'WalletProvider: backend prices unusable (source=${snapshot.source}), trying Coinbase',
      );
    } catch (e) {
      debugPrint('WalletProvider: backend price refresh failed: $e');
    }

    snapshot = await CoinbasePriceService.instance.fetchPrices();
    if (snapshot != null && snapshot.prices.isNotEmpty) {
      _applyPriceSnapshot(snapshot);
      await _refreshFearGreed();
      return;
    }

    debugPrint('WalletProvider: Coinbase fallback also failed');
    await _refreshFearGreed();
  }

  /// The live rate API quotes BTC, ETH, BNB, TRX, USDT and USDC only. Market
  /// screen symbols outside that set are filled from Coinbase.
  Future<CryptoPricesSnapshot> _withMarketFallback(
    CryptoPricesSnapshot snapshot,
  ) async {
    final missing = kMarketSymbols
        .where((symbol) => !snapshot.prices.containsKey(symbol))
        .toList();
    if (missing.isEmpty) return snapshot;

    final extra = await CoinbasePriceService.instance.fetchPrices();
    if (extra == null || extra.prices.isEmpty) return snapshot;

    return CryptoPricesSnapshot(
      prices: {
        for (final symbol in missing)
          if (extra.prices[symbol] != null) symbol: extra.prices[symbol]!,
        ...snapshot.prices,
      },
      updatedAt: snapshot.updatedAt,
      source: snapshot.source,
      stale: snapshot.stale,
    );
  }

  Future<void> _refreshFearGreed() async {
    final data = await CoinbasePriceService.instance.fetchFearGreed();
    if (data == null) return;
    fearGreed = data;
    notifyListeners();
  }

  void _applyPriceSnapshot(CryptoPricesSnapshot snapshot) {
    prices = snapshot.prices;
    pricesUpdatedAt = snapshot.updatedAt;
    pricesSource = snapshot.source;
    pricesStale = snapshot.stale;
    notifyListeners();
    unawaited(
      SessionCache.savePrices({
        'prices': snapshot.prices.map(
          (symbol, price) => MapEntry(symbol, {
            'price': price.price,
            'change24h': ?price.change24h,
          }),
        ),
        'updatedAt': ?snapshot.updatedAt,
        'source': ?snapshot.source,
        'stale': snapshot.stale,
      }),
    );
  }

  /// Fee row for the selected asset/network.
  ///
  /// The live API keys rows both ways (`USDT_TRC20` and `USDT_TRON`), so both
  /// spellings are tried.
  WithdrawalFeeInfo? feeFor({required String symbol, required String network}) {
    final sym = symbol.toUpperCase();
    for (final key in [
      ?withdrawalAssetKey(sym, network),
      '${sym}_$network',
      sym,
    ]) {
      final info = feesByAssetKey[key];
      if (info != null) return info;
    }
    return null;
  }

  String feeDisplayFor(String symbol, String network) {
    final info = feeFor(symbol: symbol, network: network);
    if (info == null || info.display.isEmpty) return '—';
    return info.display;
  }

  /// Fee for [amount], in units of [symbol]. USD fees are converted with the
  /// live rate, and percentage overrides scale with the amount.
  double feeDeductionFor(String symbol, String network, {double amount = 0}) {
    final info = feeFor(symbol: symbol, network: network);
    if (info == null) return 0;
    return info.deductionAmount(
      amount: amount,
      priceUsd: prices[symbol.toUpperCase()]?.price ?? 0,
    );
  }

  double receiverGetsAmount({
    required String symbol,
    required String network,
    required double amount,
  }) {
    final deduction = feeDeductionFor(symbol, network, amount: amount);
    if (deduction > 0) {
      return (amount - deduction).clamp(0, double.infinity);
    }
    return amount;
  }

  String feeEtaFor(String symbol, String network) {
    final info = feeFor(symbol: symbol, network: network);
    final text = info?.timeframeText;
    if (text != null && text.isNotEmpty) return text;
    return kNetworkEta[network] ?? '';
  }

  String feeLineFor(String symbol, String network) {
    final display = feeDisplayFor(symbol, network);
    if (display == '—') return '';
    final eta = feeEtaFor(symbol, network);
    return eta.isEmpty ? 'Fee $display' : 'Fee $display · $eta';
  }

  Future<Map<String, dynamic>> fetchFees() async {
    final data = await _api.fees();
    _applyFeePayload(data);
    return data;
  }

  /// Amount-aware quote: picks up percentage overrides for the signed-in user.
  Future<WithdrawalFeeInfo?> fetchFeeQuote({
    required String symbol,
    required String network,
    required double amount,
  }) async {
    try {
      final data = await _api.fees(
        asset: symbol,
        network: network,
        amount: amount,
      );
      _applyFeePayload(data);
      return feeFor(symbol: symbol, network: network);
    } catch (e) {
      debugPrint('WalletProvider: fee quote failed: $e');
      return feeFor(symbol: symbol, network: network);
    }
  }

  void _applyFeePayload(Map<String, dynamic> data) {
    feesPayload = data;
    final rows = [
      ...(data['fees'] as List<dynamic>? ?? []),
      ...(data['rows'] as List<dynamic>? ?? []),
      ...(data['feeRows'] as List<dynamic>? ?? []),
      if (data['selected'] is Map<String, dynamic>) data['selected'],
    ];

    final byKey = <String, WithdrawalFeeInfo>{};
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final info = WithdrawalFeeInfo.fromJson(row);
      for (final key in info.aliases) {
        byKey[key] = info;
      }
    }
    if (byKey.isNotEmpty) {
      feesByAssetKey = byKey;
      notifyListeners();
    }
  }

  Future<void> _refreshFees() async {
    try {
      await fetchFees();
    } catch (_) {}
  }

  Future<void> pollNotifications({
    bool showBanner = true,
    bool showLocalNotification = false,
  }) async {
    if (user == null) return;
    try {
      final notifications = await _api.popupNotifications();
      if (notifications.isEmpty) return;
      for (final item in notifications) {
        await deliverPopupNotification(
          item,
          showBanner: showBanner,
          showLocalNotification: showLocalNotification,
          onBanner: showPushNotification,
        );
      }
    } catch (_) {}
  }

  void dismissPopup() {
    activePopup = null;
    notifyListeners();
  }

  void showPushNotification(PopupNotification notification) {
    activePopup = notification;
    notifyListeners();
  }

  Future<void> registerPushToken() async {
    final push = PushService.instance;
    if (!push.isReady) return;
    await push.registerTokenWithApi(_api);
  }

  void toggleBalanceVisible() {
    balanceVisible = !balanceVisible;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    isDark = !isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_theme', isDark);
    notifyListeners();
  }

  Future<T> _guardRestrictedAction<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      if (error is ApiException && ApiClient.isSessionExpiredError(error)) {
        await _handleSessionExpired();
      }
      if (error is ApiException &&
          (error.statusCode == 423 || error.code == 'ACCOUNT_RESTRICTED')) {
        await refreshAccountFeatures();
      }
      rethrow;
    }
  }

  Future<void> _handleSessionExpired() async {
    await ApiClient.instance.clearCookies();
    await SessionCache.clear();
    user = null;
    wallet = const WalletModel();
    events = [];
    accountStatus = null;
    announcements = [];
    pendingEmailVerification = false;
    _clearPendingLogin();
    _clearPendingSignup();
    notifyListeners();
  }

  Future<DepositAddressResult> depositAddress({
    required String asset,
    required String network,
  }) {
    return _guardRestrictedAction(
      () => _api.depositAddress(asset: asset, network: network),
    );
  }

  Future<WithdrawalResult> withdraw({
    required String asset,
    required String network,
    required String amount,
    required String toAddress,
  }) async {
    final result = await _guardRestrictedAction(
      () => _api.withdrawalRequest(
        asset: asset,
        network: network,
        amount: amount,
        toAddress: toAddress,
      ),
    );
    Future.microtask(refreshWallet);
    return result;
  }

  Future<SwapEstimateResult> swapEstimate({
    required String fromAsset,
    required String fromNetwork,
    required String toAsset,
    required String toNetwork,
    required String amount,
  }) {
    return _guardRestrictedAction(
      () => _api.swapEstimate(
        fromAsset: fromAsset,
        fromNetwork: fromNetwork,
        toAsset: toAsset,
        toNetwork: toNetwork,
        amount: amount,
      ),
    );
  }

  Future<Map<String, dynamic>> swapExchange({
    required String fromAsset,
    required String fromNetwork,
    required String toAsset,
    required String toNetwork,
    required String amount,
  }) async {
    final result = await _guardRestrictedAction(
      () => _api.swapExchange(
        fromAsset: fromAsset,
        fromNetwork: fromNetwork,
        toAsset: toAsset,
        toNetwork: toNetwork,
        amount: amount,
      ),
    );
    Future.microtask(refreshWallet);
    return result;
  }

  Future<void> refreshPrices() => _refreshPrices();

  void _applySession(AuthSession session) {
    user = session.user;
    wallet = session.wallet;
    events = session.events;
    SecurityService.instance.unlock();
    Future.microtask(registerPushToken);
    Future.microtask(refreshAccountFeatures);
    Future.microtask(refreshWallet);
    final cachedUser = _cachedUserPayload();
    if (cachedUser != null) {
      unawaited(
        SessionCache.save({
          'user': cachedUser,
          'wallet': <String, dynamic>{},
          'events': <dynamic>[],
        }),
      );
    }
  }
}
