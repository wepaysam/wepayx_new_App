import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/otp_bypass.dart';
import '../core/constants/assets.dart';
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

  /// True when the signed-in user still needs the email OTP step.
  bool get needsEmailVerification {
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
      if (savedKey != null && savedKey.isNotEmpty) {
        ApiConfig.setApiKey(savedKey);
      }
      isDark = prefs.getBool('dark_theme') ?? true;

      await ApiEndpointResolver.resolveAndPersist(prefs);
      await ApiClient.instance.init();
      await restoreSession();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      initialized = true;
      notifyListeners();
    }
  }

  /// Restores the logged-in user from the persisted session cookie.
  Future<bool> restoreSession() async {
    try {
      await ApiClient.instance.init();
      final session = await _api.me();
      user = session.user;
      wallet = session.wallet;
      events = session.events;
      if (user != null) {
        await _restoreLocalEmailVerification(user!.id);
        if (OtpBypass.isExempt(user!.email)) {
          pendingEmailVerification = false;
          user = user!.copyWith(emailVerified: true);
        } else if (user!.emailVerified == false) {
          // If backend says unverified, keep forcing the OTP step.
          pendingEmailVerification = true;
        }
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
      // If the cookie token is stale/invalid, clear it so we don't keep
      // trying to use a guest session (Receive/Deposit may otherwise show
      // blank QR/address).
      await ApiClient.instance.clearCookies();
      user = null;
      wallet = const WalletModel();
      events = [];
      accountStatus = null;
      announcements = [];
      pendingEmailVerification = false;
      _clearPendingLogin();
      return false;
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
    final session = await _api.signup(
      email: email,
      password: password,
      name: name,
    );
    _applySession(session);
    pendingEmailVerification = !OtpBypass.isExempt(email);
    // New signups are unverified until OTP confirm succeeds (unless exempt).
    if (user != null && user!.emailVerified != true && !OtpBypass.isExempt(email)) {
      user = user!.copyWith(emailVerified: false);
    } else if (user != null && OtpBypass.isExempt(email)) {
      user = user!.copyWith(emailVerified: true);
    }
  }

  Future<void> requestSignupEmailVerification() async {
    final email = user?.email;
    if (email == null || email.isEmpty) {
      throw Exception('No email available for verification');
    }
    await _withApiRetry(
      () => _api.requestSignupEmailVerification(email: email),
    );
  }

  Future<void> confirmSignupEmailVerification(String otp) async {
    final email = user?.email;
    if (email == null || email.isEmpty) {
      throw Exception('No email available for verification');
    }
    final code = otp.trim();
    if (code.length < 4) {
      throw Exception('Enter the verification code from your email');
    }

    final updated = await _withApiRetry(
      () => _api.confirmSignupEmailVerification(email: email, otp: code),
    );

    if (updated != null) {
      user = updated.copyWith(emailVerified: updated.emailVerified ?? true);
    } else if (user != null) {
      user = user!.copyWith(emailVerified: true);
    }

    pendingEmailVerification = false;
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
      return;
    }

    final otpRequired = data['loginOtpRequired'] == true;
    if (otpRequired && OtpBypass.isExempt(email)) {
      // Exempt test accounts: try magic OTP confirm (local/dev). If production
      // rejects it, fall through to the normal OTP screen.
      try {
        final session = await _api.confirmLoginEmailVerification(
          email: email.trim(),
          otp: OtpBypass.magicLoginOtp,
        );
        _applySession(session);
        await _afterAuthSessionApplied();
        _clearPendingLogin();
        return;
      } catch (_) {
        // Keep going to OTP challenge below.
      }
    }

    if (otpRequired || data['ok'] == true) {
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

  Future<void> requestForgotPassword(String email) async {
    await _withApiRetry(() => _api.requestForgotPassword(email: email.trim()));
  }

  Future<void> confirmForgotPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _withApiRetry(
      () => _api.confirmForgotPassword(
        email: email.trim(),
        otp: otp.trim(),
        newPassword: newPassword,
      ),
    );
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
    try {
      await _api.logout();
    } catch (_) {}
    user = null;
    wallet = const WalletModel();
    events = [];
    accountStatus = null;
    announcements = [];
    pendingEmailVerification = false;
    _clearPendingLogin();
    await clearLastNotificationId();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    user = null;
    wallet = const WalletModel();
    events = [];
    accountStatus = null;
    announcements = [];
    pendingEmailVerification = false;
    _clearPendingLogin();
    await clearLastNotificationId();
    notifyListeners();
  }

  bool isFeatureBlocked(String feature) {
    if (needsEmailVerification) {
      // Trusted wallet actions stay locked until email OTP is confirmed.
      if (feature == 'deposit' ||
          feature == 'withdrawal' ||
          feature == 'swap') {
        return true;
      }
    }
    final status = accountStatus;
    if (status == null) return false;
    return status.isFrozen || status.blocks(feature);
  }

  Future<void> refreshAccountFeatures({bool force = false}) async {
    if (user == null) return;
    if (accountFeaturesLoading && !force) return;
    accountFeaturesLoading = true;
    try {
      try {
        accountStatus = await _api.accountStatus();
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
    try {
      final session = await _api.wallet();
      user = session.user ?? user;
      wallet = session.wallet;
      events = session.events;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _refreshPrices() async {
    CryptoPricesSnapshot? snapshot;

    try {
      snapshot = await _api.cryptoPricesRaw();
      if (isUsableBackendPrices(snapshot)) {
        _applyPriceSnapshot(snapshot);
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
  }

  WithdrawalFeeInfo? feeFor({required String symbol, required String network}) {
    final key = withdrawalAssetKey(symbol, network);
    if (key == null) return null;
    return feesByAssetKey[key];
  }

  String feeDisplayFor(String symbol, String network) {
    final info = feeFor(symbol: symbol, network: network);
    if (info == null || info.display.isEmpty) return '—';
    return info.display;
  }

  double feeDeductionFor(String symbol, String network) {
    return feeFor(symbol: symbol, network: network)?.deductionAmount(symbol) ??
        0;
  }

  double receiverGetsAmount({
    required String symbol,
    required String network,
    required double amount,
  }) {
    final deduction = feeDeductionFor(symbol, network);
    if (deduction > 0) {
      return (amount - deduction).clamp(0, double.infinity);
    }
    return amount;
  }

  String feeLineFor(String symbol, String network) {
    final display = feeDisplayFor(symbol, network);
    if (display == '—') return '';
    final eta = kNetworkEta[network] ?? '';
    return eta.isEmpty ? 'Fee $display' : 'Fee $display · $eta';
  }

  Future<Map<String, dynamic>> fetchFees() async {
    final data = await _api.fees();
    feesPayload = data;
    final rows = data['rows'] as List<dynamic>? ?? [];
    feesByAssetKey = {
      for (final row in rows.whereType<Map<String, dynamic>>())
        if ((row['assetKey'] as String?)?.isNotEmpty ?? false)
          row['assetKey'] as String: WithdrawalFeeInfo.fromJson(row),
    };
    notifyListeners();
    return data;
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
      final latest = notifications.last;
      await deliverPopupNotification(
        latest,
        showBanner: showBanner,
        showLocalNotification: showLocalNotification,
        onBanner: showPushNotification,
      );
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
    user = null;
    wallet = const WalletModel();
    events = [];
    accountStatus = null;
    announcements = [];
    pendingEmailVerification = false;
    _clearPendingLogin();
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
  }
}
