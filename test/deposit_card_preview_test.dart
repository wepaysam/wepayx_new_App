import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nex_wallet/services/deposit_card_service.dart';

/// Smoke test for the shareable/downloadable receive card. It also writes the
/// rendered PNGs to `build/deposit-card-<theme>.png` so layout and iconography
/// can be eyeballed after changes. Text renders as placeholder boxes because
/// tests have no real font, but those boxes are wider than real glyphs, so a
/// preview that fits is a safe upper bound.
void main() {
  const address = 'TVtdrUjAfCt2wWK9Vk17PktmDYkZt4LR8R';

  testWidgets('renders deposit card previews', (tester) async {
    await tester.runAsync(() async {
      for (final isDark in [true, false]) {
        final bytes = await DepositCardService.instance.buildCardBytes(
          address: address,
          symbol: 'USDT',
          network: 'TRC20',
          isDark: isDark,
        );
        final dir = Directory('build')..createSync(recursive: true);
        final file = File(
          '${dir.path}/deposit-card-${isDark ? 'dark' : 'light'}.png',
        );
        file.writeAsBytesSync(bytes);
        expect(file.lengthSync(), greaterThan(1000));
      }
    });
  });
}
