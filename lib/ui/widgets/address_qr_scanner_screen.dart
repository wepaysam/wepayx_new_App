import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/utils/address_utils.dart';
import '../nex_tokens.dart';
import 'nex_components.dart';

class AddressQrScannerScreen extends StatefulWidget {
  const AddressQrScannerScreen({super.key, required this.network});

  final String network;

  @override
  State<AddressQrScannerScreen> createState() => _AddressQrScannerScreenState();
}

class _AddressQrScannerScreenState extends State<AddressQrScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      final parsed = parseWalletAddress(raw, network: widget.network);
      if (parsed == null) continue;
      _handled = true;
      Navigator.of(context).pop(parsed);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NexThemeScope.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    NexIconButton(
                      onTap: () => Navigator.of(context).pop(),
                      icon: 'back',
                      size: 18,
                      iconColor: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan address',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Point at a ${widget.network} wallet QR code',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _controller.toggleTorch(),
                      icon: Icon(Icons.flash_on, color: t.navActive),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: t.navActive, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 32,
              child: Text(
                'The app scans locally. Your address is validated when you review the withdrawal.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
