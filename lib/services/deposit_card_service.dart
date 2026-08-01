import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/assets.dart';
import '../ui/widgets/nex_brand.dart';

class DepositCardService {
  DepositCardService._();

  static final DepositCardService instance = DepositCardService._();

  static const _blue = Color(0xFF2D8CFF);
  static const _qrInk = Color(0xFF0F172A);

  static const _networkSymbol = {
    'TRC20': 'TRX',
    'ERC20': 'ETH',
    'BEP20': 'BNB',
    'Bitcoin': 'BTC',
  };

  Future<void> share({
    required String address,
    required String symbol,
    required String network,
    bool isDark = true,
  }) async {
    final bytes = await buildCardBytes(
      address: address,
      symbol: symbol,
      network: network,
      isDark: isDark,
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
    bool isDark = true,
  }) async {
    final bytes = await buildCardBytes(
      address: address,
      symbol: symbol,
      network: network,
      isDark: isDark,
    );
    final name =
        'nex-${symbol.toLowerCase()}-${network.toLowerCase()}-deposit.png';
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

  Future<Uint8List> buildCardBytes({
    required String address,
    required String symbol,
    required String network,
    required bool isDark,
  }) async {
    const width = 750.0;
    const outerMargin = 26.0;
    const cardMargin = 44.0;
    const cardPad = 28.0;
    const cardLeft = cardMargin;
    const cardW = width - cardMargin * 2;
    const contentLeft = cardLeft + cardPad;
    const contentW = cardW - cardPad * 2;
    const cardTop = cardMargin;

    final colors = _CardColors.forTheme(isDark);
    final networkName = _shortNetworkLabel(network);
    final logo = await _loadNetworkLogo(network);

    // ---------------- Measure pass ----------------
    final brandTitle = _painter(
      'NEX',
      TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w900,
        color: colors.brandTitle,
        letterSpacing: 1.5,
        height: 1.05,
      ),
    );
    final brandSub = _painter(
      'WALLET',
      const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: _blue,
        letterSpacing: 5,
        height: 1.1,
      ),
    );

    const infoPad = 26.0;
    const infoIcon = 38.0;
    const infoGap = 22.0;
    final infoText = _painter(
      _warningText(network, symbol),
      TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w500,
        color: colors.text,
        height: 1.5,
      ),
      maxWidth: contentW - infoPad * 2 - infoIcon - infoGap,
      maxLines: 4,
    );

    // ---------------- Layout ----------------
    final brandTop = cardTop + 38;
    final brandBlockH = brandTitle.height + 8 + brandSub.height;
    const brandMark = 46.0;
    const brandMarkGap = 18.0;
    final brandW = brandMark + brandMarkGap + brandTitle.width;
    final brandLeft = (width - brandW) / 2;

    final infoTop = brandTop + brandBlockH + 34;
    final infoH = infoText.height + infoPad * 2;
    final infoRect = Rect.fromLTWH(contentLeft, infoTop, contentW, infoH);

    const panelSize = 424.0;
    const qrSize = 330.0;
    final panelTop = infoRect.bottom + 32;
    final panelRect = Rect.fromLTWH(
      (width - panelSize) / 2,
      panelTop,
      panelSize,
      panelSize,
    );

    final addrRect = Rect.fromLTWH(contentLeft, panelRect.bottom + 32, contentW, 86);
    final splitRect = Rect.fromLTWH(contentLeft, addrRect.bottom + 22, contentW, 112);

    final cardH = splitRect.bottom + cardPad - cardTop;
    final cardRect = Rect.fromLTWH(cardLeft, cardTop, cardW, cardH);

    final footerCenterY = cardRect.bottom + 58;
    final height = footerCenterY + 42 + outerMargin;

    // ---------------- Paint pass ----------------
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = colors.bg,
    );
    _drawBackdropGlow(canvas, width, height, colors);

    _roundRectStroke(
      canvas,
      Rect.fromLTWH(
        outerMargin,
        outerMargin,
        width - outerMargin * 2,
        height - outerMargin * 2,
      ),
      32,
      colors.frameBorder,
      strokeWidth: 2,
    );

    _roundRect(canvas, cardRect, 26, colors.cardFill);
    _roundRectStroke(canvas, cardRect, 26, colors.cardBorder, strokeWidth: 1.5);

    // Brand header
    _drawNexMark(
      canvas,
      Rect.fromLTWH(
        brandLeft,
        brandTop + (brandBlockH - brandMark) / 2,
        brandMark,
        brandMark,
      ),
    );
    _paint(canvas, brandTitle, Offset(brandLeft + brandMark + brandMarkGap, brandTop));
    _paint(
      canvas,
      brandSub,
      Offset(
        brandLeft + brandMark + brandMarkGap + 3,
        brandTop + brandTitle.height + 8,
      ),
    );

    // Info banner
    _roundRect(canvas, infoRect, 20, colors.infoFill);
    _roundRectStroke(canvas, infoRect, 20, colors.infoBorder, strokeWidth: 1.5);
    _drawInfoIcon(
      canvas,
      Offset(infoRect.left + infoPad + infoIcon / 2, infoRect.center.dy),
      infoIcon / 2,
      colors,
    );
    _paint(
      canvas,
      infoText,
      Offset(infoRect.left + infoPad + infoIcon + infoGap, infoRect.top + infoPad),
    );

    // QR panel (always light so the code stays scannable)
    _drawSoftShadow(canvas, panelRect, 24, colors.panelShadow);
    _roundRect(canvas, panelRect, 24, Colors.white);
    _roundRectStroke(canvas, panelRect, 24, colors.qrPanelBorder, strokeWidth: 1.5);

    final qrLeft = panelRect.left + (panelSize - qrSize) / 2;
    final qrTop = panelRect.top + (panelSize - qrSize) / 2;
    final qrPainter = QrPainter(
      data: address,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: _qrInk,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: _qrInk,
      ),
    );
    canvas.save();
    canvas.translate(qrLeft, qrTop);
    qrPainter.paint(canvas, const Size(qrSize, qrSize));
    canvas.restore();

    _drawQrCorners(canvas, panelRect.deflate(22), _blue);

    // Address row
    _roundRect(canvas, addrRect, 18, colors.addrFill);
    _roundRectStroke(canvas, addrRect, 18, colors.addrBorder, strokeWidth: 1.5);
    const addrPad = 26.0;
    const copyBox = 44.0;
    final addrText = _fittedPainter(
      address,
      (size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: colors.text,
        letterSpacing: -0.1,
      ),
      maxWidth: addrRect.width - addrPad * 2 - copyBox - 16,
      maxSize: 20,
      minSize: 12,
    );
    _paint(
      canvas,
      addrText,
      Offset(addrRect.left + addrPad, addrRect.center.dy - addrText.height / 2),
    );
    _drawCopyIcon(
      canvas,
      Offset(addrRect.right - addrPad - copyBox / 2, addrRect.center.dy),
      copyBox,
      colors,
    );

    // Network + trust split bar
    _roundRect(canvas, splitRect, 20, colors.splitFill);
    _roundRectStroke(canvas, splitRect, 20, colors.splitBorder, strokeWidth: 1.5);

    final dividerX = splitRect.left + splitRect.width * 0.47;
    canvas.drawLine(
      Offset(dividerX, splitRect.top + 26),
      Offset(dividerX, splitRect.bottom - 26),
      Paint()
        ..color = colors.divider
        ..strokeWidth = 1.5,
    );

    const badge = 46.0;
    final badgeCenter = Offset(splitRect.left + 26 + badge / 2, splitRect.center.dy);
    _drawNetworkBadge(canvas, badgeCenter, badge, network, logo);

    final netLabelLeft = badgeCenter.dx + badge / 2 + 20;
    final netLabelMaxW = dividerX - 22 - netLabelLeft;
    final netCaption = _painter(
      'Network',
      TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: colors.muted,
        letterSpacing: 0.2,
      ),
      maxWidth: netLabelMaxW,
      maxLines: 1,
    );
    final netValue = _fittedPainter(
      networkName,
      (size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: colors.text,
      ),
      maxWidth: netLabelMaxW,
      maxSize: 21,
      minSize: 15,
    );
    final netBlockH = netCaption.height + 4 + netValue.height;
    final netTop = splitRect.center.dy - netBlockH / 2;
    _paint(canvas, netCaption, Offset(netLabelLeft, netTop));
    _paint(canvas, netValue, Offset(netLabelLeft, netTop + netCaption.height + 4));

    const shield = 40.0;
    final shieldCenter = Offset(dividerX + 26 + shield / 2, splitRect.center.dy);
    _drawShieldCheck(canvas, shieldCenter, shield, _blue);

    final trustLeft = shieldCenter.dx + shield / 2 + 18;
    final trustMaxW = splitRect.right - 24 - trustLeft;
    final trustTitle = _fittedPainter(
      'Secure • Fast • Reliable',
      (size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: colors.text,
      ),
      maxWidth: trustMaxW,
      maxSize: 17,
      minSize: 13,
    );
    final trustSub = _fittedPainter(
      'Powered by ${_poweredBy(network)}',
      (size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: colors.muted,
      ),
      maxWidth: trustMaxW,
      maxSize: 15,
      minSize: 12,
    );
    final trustBlockH = trustTitle.height + 4 + trustSub.height;
    final trustTop = splitRect.center.dy - trustBlockH / 2;
    _paint(canvas, trustTitle, Offset(trustLeft, trustTop));
    _paint(canvas, trustSub, Offset(trustLeft, trustTop + trustTitle.height + 4));

    // Footer
    _drawFooter(canvas, width, footerCenterY, colors);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    logo?.picture.dispose();
    return data!.buffer.asUint8List();
  }

  Future<PictureInfo?> _loadNetworkLogo(String network) async {
    final symbol = _networkSymbol[network];
    if (symbol == null) return null;
    try {
      return await vg.loadPicture(
        SvgAssetLoader('assets/coins/$symbol.svg'),
        null,
      );
    } catch (_) {
      return null;
    }
  }

  String _shortNetworkLabel(String network) {
    switch (network) {
      case 'TRC20':
        return 'TRON (TRC-20)';
      case 'ERC20':
        return 'Ethereum (ERC-20)';
      case 'BEP20':
        return 'BNB Chain (BEP-20)';
      case 'Bitcoin':
        return 'Bitcoin';
      default:
        return networkLabel(network);
    }
  }

  String _warningText(String network, String symbol) {
    switch (network) {
      case 'TRC20':
        return 'You can only transfer TRON-based tokens (e.g. TRX or TRC10/20/721 tokens) to this address. Transfers of other tokens cannot be revoked.';
      case 'ERC20':
        return 'You can only transfer $symbol on Ethereum (ERC-20) to this address. Transfers of other tokens or networks cannot be revoked.';
      case 'BEP20':
        return 'You can only transfer $symbol on BNB Smart Chain (BEP-20) to this address. Transfers of other tokens or networks cannot be revoked.';
      case 'Bitcoin':
        return 'You can only transfer Bitcoin (BTC) to this address. Transfers of other tokens or networks cannot be revoked.';
      default:
        return 'You can only transfer $symbol on ${networkLabel(network)} to this address. Transfers of other tokens cannot be revoked.';
    }
  }

  String _poweredBy(String network) {
    switch (network) {
      case 'TRC20':
        return 'TRON';
      case 'ERC20':
        return 'Ethereum';
      case 'BEP20':
        return 'BNB Chain';
      case 'Bitcoin':
        return 'Bitcoin';
      default:
        return networkLabel(network);
    }
  }

  void _drawFooter(Canvas canvas, double width, double centerY, _CardColors colors) {
    const mark = 30.0;
    final left = 72.0;
    _drawNexMark(canvas, Rect.fromLTWH(left, centerY - mark / 2, mark, mark));

    final title = _painter(
      'NEX',
      TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: colors.brandTitle,
        letterSpacing: 1,
        height: 1.05,
      ),
    );
    final sub = _painter(
      'WALLET',
      const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: _blue,
        letterSpacing: 3,
        height: 1.1,
      ),
    );
    final blockH = title.height + 3 + sub.height;
    final textLeft = left + mark + 12;
    _paint(canvas, title, Offset(textLeft, centerY - blockH / 2));
    _paint(canvas, sub, Offset(textLeft + 1, centerY - blockH / 2 + title.height + 3));

    const shield = 30.0;
    final shieldCenter = Offset(width - 72 - shield / 2, centerY);
    _drawShieldCheck(canvas, shieldCenter, shield, _blue);

    final url = _painter(
      'nexwallet.app',
      const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: _blue,
      ),
    );
    final urlRight = shieldCenter.dx - shield / 2 - 24;
    _paint(
      canvas,
      url,
      Offset(urlRight - url.width, centerY - url.height / 2),
    );

    canvas.drawLine(
      Offset(urlRight + 12, centerY - 13),
      Offset(urlRight + 12, centerY + 13),
      Paint()
        ..color = colors.divider
        ..strokeWidth = 1.5,
    );
  }

  void _drawBackdropGlow(
    Canvas canvas,
    double width,
    double height,
    _CardColors colors,
  ) {
    void glow(Offset center, double radius) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [colors.glow, colors.glow.withValues(alpha: 0)],
            stops: const [0, 1],
          ).createShader(rect),
      );
    }

    glow(Offset(width * 0.05, height * 0.28), 260);
    glow(Offset(width * 0.98, height * 0.74), 300);
  }

  void _drawSoftShadow(Canvas canvas, Rect rect, double radius, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(0, 8), Radius.circular(radius)),
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  void _drawNexMark(Canvas canvas, Rect box) {
    paintNexLogoMark(canvas, box, strokeWidth: box.width * 0.062);
  }

  void _drawInfoIcon(Canvas canvas, Offset center, double radius, _CardColors colors) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawCircle(
      center,
      radius - 1.2,
      Paint()..color = colors.infoIconFill,
    );
    canvas.drawCircle(
      center.translate(0, -radius * 0.42),
      2.4,
      Paint()..color = _blue,
    );
    canvas.drawLine(
      center.translate(0, -radius * 0.12),
      center.translate(0, radius * 0.5),
      Paint()
        ..color = _blue
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCopyIcon(Canvas canvas, Offset center, double box, _CardColors colors) {
    _roundRect(
      canvas,
      Rect.fromCenter(center: center, width: box, height: box),
      12,
      colors.copyFill,
    );

    final stroke = Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;

    const sheet = 16.0;
    const shift = 4.0;
    final back = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        center.dx - sheet / 2 - shift,
        center.dy - sheet / 2 - shift,
        sheet,
        sheet,
      ),
      const Radius.circular(4),
    );
    final front = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        center.dx - sheet / 2 + shift,
        center.dy - sheet / 2 + shift,
        sheet,
        sheet,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(back, stroke);
    // Knock the back sheet out from under the front one so the two pages read
    // as stacked instead of crossed.
    canvas.drawRRect(front.inflate(2), Paint()..color = colors.copyFill);
    canvas.drawRRect(front, stroke);
  }

  void _drawShieldCheck(Canvas canvas, Offset center, double size, Color color) {
    final w = size * 0.86;
    final h = size;
    final l = center.dx - w / 2;
    final r = center.dx + w / 2;
    final t = center.dy - h / 2;
    final b = center.dy + h / 2;

    final shield = Path()
      ..moveTo(center.dx, t)
      ..lineTo(r, t + h * 0.19)
      ..lineTo(r, t + h * 0.52)
      ..cubicTo(r, t + h * 0.80, center.dx + w * 0.24, b - h * 0.02, center.dx, b)
      ..cubicTo(center.dx - w * 0.24, b - h * 0.02, l, t + h * 0.80, l, t + h * 0.52)
      ..lineTo(l, t + h * 0.19)
      ..close();
    canvas.drawPath(shield, Paint()..color = color);

    final check = Path()
      ..moveTo(center.dx - w * 0.24, center.dy - h * 0.02)
      ..lineTo(center.dx - w * 0.05, center.dy + h * 0.16)
      ..lineTo(center.dx + w * 0.26, center.dy - h * 0.17);
    canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.11
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawNetworkBadge(
    Canvas canvas,
    Offset center,
    double size,
    String network,
    PictureInfo? logo,
  ) {
    final rect = Rect.fromCenter(center: center, width: size, height: size);

    if (logo != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(rect));
      canvas.translate(rect.left, rect.top);
      canvas.scale(
        rect.width / logo.size.width,
        rect.height / logo.size.height,
      );
      canvas.drawPicture(logo.picture);
      canvas.restore();
      return;
    }

    canvas.drawCircle(center, size / 2, Paint()..color = _blue);
    final fallback = _networkSymbol[network] ?? network;
    final label = _painter(
      fallback.length <= 3 ? fallback : fallback.substring(0, 3),
      TextStyle(
        fontSize: size * 0.34,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    );
    _paint(
      canvas,
      label,
      Offset(center.dx - label.width / 2, center.dy - label.height / 2),
    );
  }

  void _drawQrCorners(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const arm = 30.0;
    const radius = 14.0;

    void corner(Offset pivot, double sx, double sy) {
      final path = Path()
        ..moveTo(pivot.dx + sx * arm, pivot.dy)
        ..lineTo(pivot.dx + sx * radius, pivot.dy)
        ..quadraticBezierTo(
          pivot.dx,
          pivot.dy,
          pivot.dx,
          pivot.dy + sy * radius,
        )
        ..lineTo(pivot.dx, pivot.dy + sy * arm);
      canvas.drawPath(path, paint);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);
  }

  void _roundRect(Canvas canvas, Rect rect, double radius, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = color,
    );
  }

  void _roundRectStroke(
    Canvas canvas,
    Rect rect,
    double radius,
    Color color, {
    double strokeWidth = 1.5,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  TextPainter _painter(
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
    int maxLines = 1,
    TextAlign align = TextAlign.left,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }

  /// Lays the text out at the largest size that still fits on a single line.
  TextPainter _fittedPainter(
    String text,
    TextStyle Function(double size) styleFor, {
    required double maxWidth,
    required double maxSize,
    required double minSize,
  }) {
    var size = maxSize;
    var painter = _painter(text, styleFor(size));
    while (painter.width > maxWidth && size > minSize) {
      size -= 1;
      painter = _painter(text, styleFor(size));
    }
    if (painter.width > maxWidth) {
      painter = _painter(text, styleFor(size), maxWidth: maxWidth, maxLines: 1);
    }
    return painter;
  }

  void _paint(Canvas canvas, TextPainter painter, Offset topLeft) {
    painter.paint(canvas, topLeft);
  }
}

class _CardColors {
  const _CardColors({
    required this.bg,
    required this.glow,
    required this.frameBorder,
    required this.cardFill,
    required this.cardBorder,
    required this.infoFill,
    required this.infoBorder,
    required this.infoIconFill,
    required this.qrPanelBorder,
    required this.panelShadow,
    required this.addrFill,
    required this.addrBorder,
    required this.copyFill,
    required this.splitFill,
    required this.splitBorder,
    required this.divider,
    required this.text,
    required this.muted,
    required this.brandTitle,
  });

  final Color bg;
  final Color glow;
  final Color frameBorder;
  final Color cardFill;
  final Color cardBorder;
  final Color infoFill;
  final Color infoBorder;
  final Color infoIconFill;
  final Color qrPanelBorder;
  final Color panelShadow;
  final Color addrFill;
  final Color addrBorder;
  final Color copyFill;
  final Color splitFill;
  final Color splitBorder;
  final Color divider;
  final Color text;
  final Color muted;
  final Color brandTitle;

  factory _CardColors.forTheme(bool isDark) {
    if (isDark) {
      return const _CardColors(
        bg: Color(0xFF070C16),
        glow: Color(0x142D8CFF),
        frameBorder: Color(0x332D8CFF),
        cardFill: Color(0xFF0D1524),
        cardBorder: Color(0x1F3B82F6),
        infoFill: Color(0xFF12203A),
        infoBorder: Color(0x4D3B82F6),
        infoIconFill: Color(0x1A3B82F6),
        qrPanelBorder: Color(0x1FFFFFFF),
        panelShadow: Color(0x33000000),
        addrFill: Color(0xFF111C2F),
        addrBorder: Color(0x333B82F6),
        copyFill: Color(0xFF16243D),
        splitFill: Color(0xFF111C2F),
        splitBorder: Color(0x333B82F6),
        divider: Color(0x333B82F6),
        text: Color(0xFFF8FAFC),
        muted: Color(0xFF94A3B8),
        brandTitle: Color(0xFFFFFFFF),
      );
    }
    return const _CardColors(
      bg: Color(0xFFEEF3FB),
      glow: Color(0x142D8CFF),
      frameBorder: Color(0xFFDCE5F2),
      cardFill: Color(0xFFFFFFFF),
      cardBorder: Color(0xFFE8EEF7),
      infoFill: Color(0xFFF1F7FF),
      infoBorder: Color(0xFFCFE1FB),
      infoIconFill: Color(0x00FFFFFF),
      qrPanelBorder: Color(0xFFE8EEF7),
      panelShadow: Color(0x14203A6B),
      addrFill: Color(0xFFF8FAFD),
      addrBorder: Color(0xFFE2E9F3),
      copyFill: Color(0xFFEAF2FE),
      splitFill: Color(0xFFF8FAFD),
      splitBorder: Color(0xFFE2E9F3),
      divider: Color(0xFFE2E9F3),
      text: Color(0xFF0F172A),
      muted: Color(0xFF64748B),
      brandTitle: Color(0xFF0F172A),
    );
  }
}
