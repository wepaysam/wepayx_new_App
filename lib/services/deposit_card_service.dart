import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/assets.dart';

class DepositCardService {
  DepositCardService._();

  static final DepositCardService instance = DepositCardService._();

  Future<void> share({
    required String address,
    required String symbol,
    required String network,
  }) async {
    final bytes = await _generateCardBytes(
      address: address,
      symbol: symbol,
      network: network,
    );
    final file = await _writeTemp(bytes, symbol, network);
    final networkName = networkLabel(network);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text:
          'Send $symbol on $networkName to this NEX Wallet address:\n$address',
      subject: 'NEX Wallet — Receive $symbol',
    );
  }

  Future<void> download({
    required String address,
    required String symbol,
    required String network,
  }) async {
    final bytes = await _generateCardBytes(
      address: address,
      symbol: symbol,
      network: network,
    );
    final name = 'nex-${symbol.toLowerCase()}-${network.toLowerCase()}-deposit.png';
    await Gal.putImageBytes(bytes, name: name);
  }

  Future<File> _writeTemp(Uint8List bytes, String symbol, String network) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/nex-${symbol.toLowerCase()}-${network.toLowerCase()}-deposit.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Uint8List> _generateCardBytes({
    required String address,
    required String symbol,
    required String network,
  }) async {
    const width = 750.0;
    const height = 1100.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEEF2FF), Color(0xFFF8FAFC), Color(0xFFDBEAFE)],
      ).createShader(const Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bg);

    _drawText(
      canvas,
      'Scan QR Code and Pay',
      width / 2,
      96,
      const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
    );

    _roundRect(canvas, const Rect.fromLTWH(28, 150, 694, 720), 14, const Color(0xC8FFFFFF));

    final networkName = networkLabel(network);
    _drawText(
      canvas,
      'You can only transfer $networkName $symbol to this address.',
      width / 2,
      210,
      const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
      maxWidth: 610,
      maxLines: 3,
    );

    _roundRect(canvas, const Rect.fromLTWH(170, 300, 410, 410), 12, Colors.white);
    final qrPainter = QrPainter(
      data: address,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF0F172A),
      ),
    );
    canvas.save();
    canvas.translate(190, 320);
    qrPainter.paint(canvas, const Size(370, 370));
    canvas.restore();

    _roundRect(canvas, const Rect.fromLTWH(64, 740, 622, 96), 12, const Color(0xFFE2E8F0));
    _drawText(
      canvas,
      symbol,
      width / 2,
      792,
      const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
    );
    _drawText(
      canvas,
      networkName,
      width / 2,
      828,
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
    );

    final shortAddr = address.length > 42
        ? '${address.substring(0, 18)}...${address.substring(address.length - 14)}'
        : address;
    _drawText(
      canvas,
      shortAddr,
      width / 2,
      900,
      const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
      maxWidth: 650,
    );

    canvas.drawRect(const Rect.fromLTWH(0, 980, width, 120), Paint()..color = const Color(0xFFE2E8F0));
    _drawText(
      canvas,
      'NEX Wallet',
      116,
      1040,
      const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
      align: TextAlign.left,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  void _roundRect(Canvas canvas, Rect rect, double radius, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = color,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y,
    TextStyle style, {
    TextAlign align = TextAlign.center,
    double maxWidth = 600,
    int maxLines = 2,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    final offsetX = switch (align) {
      TextAlign.center => x - painter.width / 2,
      TextAlign.right => x - painter.width,
      _ => x,
    };
    painter.paint(canvas, Offset(offsetX, y));
  }
}
