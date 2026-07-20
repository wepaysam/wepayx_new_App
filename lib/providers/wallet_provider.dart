import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
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
  bool balanceVisible = true;
  bool isDark = true;
  bool loading = false;
  bool initialized = false;
  String? error;

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
      notifyListeners();
      unawaited(
        Future.wait([
          _refreshPrices(),
          _refreshFees(),
        ]).catchError((_) => <void>[]),
      );
      return user != null;
    } catch (e) {
      error = e.toString();
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
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _withApiRetry(
        () => _loginOnce(email: email, password: password),
      );
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loginOnce({
    required String email,
    required String password,
  }) async {
    final session = await _api.login(email: email, password: password);
    _applySession(session);
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    user = null;
    wallet = const WalletModel();
    events = [];
    await clearLastNotificationId();
    notifyListeners();
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
      debugPrint('WalletProvider: backend prices unusable (source=${snapshot.source}), trying Coinbase');
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
    return feeFor(symbol: symbol, network: network)?.deductionAmount(symbol) ?? 0;
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

  Future<DepositAddressResult> depositAddress({
    required String asset,
    required String network,
  }) {
    return _api.depositAddress(asset: asset, network: network);
  }

  Future<WithdrawalResult> withdraw({
    required String asset,
    required String network,
    required String amount,
    required String toAddress,
  }) async {
    final result = await _api.withdrawalRequest(
      asset: asset,
      network: network,
      amount: amount,
      toAddress: toAddress,
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
    return _api.swapEstimate(
      fromAsset: fromAsset,
      fromNetwork: fromNetwork,
      toAsset: toAsset,
      toNetwork: toNetwork,
      amount: amount,
    );
  }

  Future<Map<String, dynamic>> swapExchange({
    required String fromAsset,
    required String fromNetwork,
    required String toAsset,
    required String toNetwork,
    required String amount,
  }) async {
    final result = await _api.swapExchange(
      fromAsset: fromAsset,
      fromNetwork: fromNetwork,
      toAsset: toAsset,
      toNetwork: toNetwork,
      amount: amount,
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
  }
}
