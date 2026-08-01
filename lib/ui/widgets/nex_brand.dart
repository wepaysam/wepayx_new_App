import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NexIcon extends StatelessWidget {
  const NexIcon(
    this.name, {
    super.key,
    this.size = 20,
    this.color,
    this.strokeWidth = 2,
  });

  final String name;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}

class NexLogo extends StatelessWidget {
  const NexLogo({super.key, this.size = 40, this.strokeWidth = 2.4});

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _NexLogoPainter(strokeWidth: strokeWidth),
    );
  }
}

/// Paints the NEX shield-and-N mark inside [box]. Shared by [NexLogo] and by
/// offscreen canvases such as the downloadable deposit card.
void paintNexLogoMark(Canvas canvas, Rect box, {double strokeWidth = 2.4}) {
  canvas.save();
  canvas.translate(box.left, box.top);
  canvas.scale(box.width / 48);
  _paintNexLogo(canvas, strokeWidth);
  canvas.restore();
}

class _NexLogoPainter extends CustomPainter {
  _NexLogoPainter({required this.strokeWidth});

  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48;
    canvas.scale(scale);
    _paintNexLogo(canvas, strokeWidth);
  }

  @override
  bool shouldRepaint(covariant _NexLogoPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth;
}

void _paintNexLogo(Canvas canvas, double strokeWidth) {
  const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5CC8FF), Color(0xFF2B8CFF), Color(0xFF0F4FE0)],
    stops: [0, 0.55, 1],
  );
  const rect = Rect.fromLTWH(0, 0, 48, 48);
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..shader = gradient.createShader(rect)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  final shield = Path()
    ..moveTo(24, 3.5)
    ..lineTo(41, 11.3)
    ..lineTo(41, 25.2)
    ..cubicTo(41, 35, 33.4, 41.8, 24, 44.8)
    ..cubicTo(14.6, 41.8, 7, 35, 7, 25.2)
    ..lineTo(7, 11.3)
    ..close();
  canvas.drawPath(
    shield,
    Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x0F2D8CFF),
  );
  canvas.drawPath(shield, paint);

  final nPath = Path()
    ..moveTo(17.5, 32)
    ..lineTo(17.5, 17)
    ..lineTo(30.5, 32)
    ..lineTo(30.5, 17);
  canvas.drawPath(nPath, paint..strokeWidth = strokeWidth + 1.1);
}

class CoinLogo extends StatelessWidget {
  const CoinLogo({
    super.key,
    required this.symbol,
    this.color,
    this.size = 44,
  });

  final String symbol;
  final Color? color;
  final double size;

  static const _bundledSvgs = {
    'BTC',
    'ETH',
    'SOL',
    'BNB',
    'USDT',
    'USDC',
    'TRX',
    'QNT',
    'ETC',
  };

  static const _bundledPngs = {
    'RENDER',
  };

  @override
  Widget build(BuildContext context) {
    final sym = symbol.toUpperCase();
    if (_bundledPngs.contains(sym)) {
      return ClipOval(
        child: Image.asset(
          'assets/coins/$sym.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    if (!_bundledSvgs.contains(sym)) {
      return ClipOval(child: _fallback());
    }

    return ClipOval(
      child: SvgPicture.asset(
        'assets/coins/$sym.svg',
        width: size,
        height: size,
        placeholderBuilder: (_) => _fallback(),
        errorBuilder: (_, __, ___) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    final c = color ?? const Color(0xFF888888);
    final sym = symbol.toUpperCase();
    final label = sym.length <= 4 ? sym : sym.substring(0, 3);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

class TokenNetworkLogo extends StatelessWidget {
  const TokenNetworkLogo({
    super.key,
    required this.symbol,
    required this.network,
    this.size = 54,
    this.badgeSize = 20,
    this.color,
  });

  final String symbol;
  final String network;
  final double size;
  final double badgeSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CoinLogo(symbol: symbol, color: color, size: size),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: NetworkIcon(network: network, size: badgeSize),
            ),
          ),
        ],
      ),
    );
  }
}

class NetworkIcon extends StatelessWidget {
  const NetworkIcon({super.key, required this.network, this.size = 32});

  final String network;
  final double size;

  static const _map = {
    'TRC20': 'TRX',
    'ERC20': 'ETH',
    'BEP20': 'BNB',
    'Bitcoin': 'BTC',
  };

  static const _colors = {
    'TRC20': Color(0xFFEF4444),
    'ERC20': Color(0xFF6366F1),
    'BEP20': Color(0xFFEAB308),
    'Bitcoin': Color(0xFFF97316),
  };

  @override
  Widget build(BuildContext context) {
    final symbol = _map[network] ?? network;
    return CoinLogo(
      symbol: symbol,
      color: _colors[network],
      size: size,
    );
  }
}

Color hexToRgba(String hex, double alpha) {
  final h = hex.replaceAll('#', '');
  final r = int.parse(h.substring(0, 2), radix: 16);
  final g = int.parse(h.substring(2, 4), radix: 16);
  final b = int.parse(h.substring(4, 6), radix: 16);
  return Color.fromRGBO(r, g, b, alpha);
}
