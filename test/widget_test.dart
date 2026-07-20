import 'package:flutter_test/flutter_test.dart';
import 'package:nex_wallet/providers/wallet_provider.dart';
import 'package:provider/provider.dart';

import 'package:nex_wallet/ui/nex_app.dart';

void main() {
  testWidgets('App boots to landing screen', (tester) async {
    final provider = WalletProvider();
    await provider.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const NexMaterialApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Create a New Wallet'), findsOneWidget);
  });
}
