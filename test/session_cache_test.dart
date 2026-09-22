import 'package:flutter_test/flutter_test.dart';
import 'package:nex_wallet/models/api_models.dart';
import 'package:nex_wallet/models/wallet_model.dart';
import 'package:nex_wallet/services/session_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The cold-start snapshot stores the raw `/api/me` payload, so re-reading it
/// must rebuild the same session models the live response would produce.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final mePayload = <String, dynamic>{
    'user': {
      'id': 22,
      'email': 'jatpay@gmail.com',
      'name': 'Jat',
      'created_at': '2026-01-02T03:04:05Z',
      'emailVerified': true,
    },
    'wallet': {
      'addresses': {'USDT-TRC20': 'TVtdrUjAfCt2wWK9Vk17PktmDYkZt4LR8R'},
      'balances': [
        {'asset': 'usdt', 'network': 'TRC20', 'balance': '125.5'},
        {'asset': 'BTC', 'network': 'Bitcoin', 'balance': 0.004},
      ],
      'activity': [
        {
          'id': 9,
          'type': 'withdrawal',
          'asset': 'USDT',
          'network': 'TRC20',
          'amount': '-10',
          'status': 'confirmed',
        },
      ],
    },
    'events': [
      {'action': 'login', 'detail': 'app', 'created_at': '2026-01-02'},
    ],
  };

  test('session snapshot round-trips into the same models', () async {
    await SessionCache.save(mePayload);

    final cached = await SessionCache.read();
    expect(cached, isNotNull);

    final live = AuthSession.fromJson(mePayload);
    final restored = AuthSession.fromJson(cached!);

    expect(restored.user!.id, live.user!.id);
    expect(restored.user!.email, 'jatpay@gmail.com');
    expect(restored.user!.emailVerified, isTrue);
    expect(restored.wallet.addresses, live.wallet.addresses);
    expect(restored.events.length, 1);

    expect(restored.wallet.balances.length, 2);
    expect(restored.wallet.balances.first.asset, 'USDT');
    expect(restored.wallet.balances.first.balance, 125.5);

    expect(restored.wallet.activity.single.type, 'sent');
    expect(restored.wallet.activity.single.amount, 10);
  });

  test('snapshot without a user is never stored', () async {
    await SessionCache.save({'user': null, 'wallet': {}, 'events': []});
    expect(await SessionCache.read(), isNull);
  });

  test('clear drops the session but keeps market prices', () async {
    await SessionCache.save(mePayload);
    await SessionCache.savePrices({
      'prices': {
        'BTC': {'price': 111000.0, 'change24h': 1.5},
      },
      'source': 'coinbase',
      'stale': false,
    });

    await SessionCache.clear();

    expect(await SessionCache.read(), isNull);
    final prices = await SessionCache.readPrices();
    expect(prices, isNotNull);

    final snapshot = CryptoPricesSnapshot.fromJson(prices!);
    expect(snapshot.prices['BTC']!.price, 111000.0);
    expect(snapshot.prices['BTC']!.change24h, 1.5);
    expect(snapshot.source, 'coinbase');
    expect(snapshot.stale, isFalse);
  });
}
