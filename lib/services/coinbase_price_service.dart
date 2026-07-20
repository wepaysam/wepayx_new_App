import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/assets.dart';
import '../models/api_models.dart';

/// Fetches spot prices from Coinbase public APIs when the Futre backend is unavailable.
class CoinbasePriceService {
  CoinbasePriceService._();

  static final CoinbasePriceService instance = CoinbasePriceService._();

  static const _coinbaseApi = 'https://api.coinbase.com/v2';
  static const _exchangeApi = 'https://api.exchange.coinbase.com';

  /// Coinbase currency codes that differ from our market symbols.
  static const _symbolMap = {
    'RENDER': 'RNDR',
  };

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: {'Accept': 'application/json'},
    ),
  );

  String _coinbaseCode(String symbol) => _symbolMap[symbol] ?? symbol;

  String _productId(String symbol) => '${_coinbaseCode(symbol)}-USD';

  Future<CryptoPricesSnapshot?> fetchPrices([List<String> symbols = kMarketSymbols]) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_coinbaseApi/exchange-rates',
        queryParameters: {'currency': 'USD'},
      );
      final rates = response.data?['data']?['rates'] as Map<String, dynamic>? ?? {};
      final prices = <String, CryptoPrice>{};

      for (final symbol in symbols) {
        final code = _coinbaseCode(symbol);
        final rate = double.tryParse('${rates[code]}');
        if (rate == null || rate <= 0) continue;
        prices[symbol] = CryptoPrice(price: 1 / rate);
      }

      if (prices.isEmpty) return null;

      await _apply24hChange(prices, symbols);

      return CryptoPricesSnapshot(
        prices: prices,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        source: 'coinbase',
        stale: false,
      );
    } catch (e, st) {
      debugPrint('CoinbasePriceService: fetch failed: $e\n$st');
      return null;
    }
  }

  Future<void> _apply24hChange(Map<String, CryptoPrice> prices, List<String> symbols) async {
    final tasks = symbols.where(prices.containsKey).map((symbol) async {
      try {
        final stats = await _dio.get<Map<String, dynamic>>(
          '$_exchangeApi/products/${_productId(symbol)}/stats',
        );
        final open = double.tryParse('${stats.data?['open']}');
        final last = double.tryParse('${stats.data?['last']}');
        if (open == null || last == null || open <= 0) return;
        final change24h = ((last - open) / open) * 100;
        final current = prices[symbol]!;
        prices[symbol] = CryptoPrice(price: current.price, change24h: change24h);
      } catch (_) {
        // Spot price is enough if stats are unavailable for this pair.
      }
    });
    await Future.wait(tasks);
  }

  /// Crypto Fear & Greed Index (public API used with Coinbase client fallback).
  Future<FearGreedIndex?> fetchFearGreed() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.alternative.me/fng/',
        queryParameters: {'limit': '1'},
      );
      final rows = response.data?['data'];
      if (rows is! List || rows.isEmpty) return null;
      final row = rows.first;
      if (row is! Map<String, dynamic>) return null;
      final value = int.tryParse('${row['value']}');
      final classification = row['value_classification'] as String? ?? 'Neutral';
      if (value == null) return null;
      return FearGreedIndex(value: value, classification: classification);
    } catch (e, st) {
      debugPrint('CoinbasePriceService: fear/greed fetch failed: $e\n$st');
      return null;
    }
  }
}

bool isUsableBackendPrices(CryptoPricesSnapshot snapshot) {
  if (snapshot.prices.isEmpty) return false;
  if (snapshot.source == 'fallback') return false;
  return true;
}
