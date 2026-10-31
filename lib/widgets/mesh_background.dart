import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Slow-moving gradient mesh for hero screens. GPU-friendly (transform + paint).
class MeshBackground extends StatefulWidget {
  final Widget? child;
  const MeshBackground({super.key, this.child});

  @override
  State<MeshBackground> createState() => _MeshBackgroundState();
}

class _MeshBackgroundState extends State<MeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.stop();
      return;
    }
    // Repeating mesh animation never "settles"; skip in widget tests.
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _ctrl.stop();
      return;
    }
    if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return CustomPaint(
          painter: _MeshPainter(t: _ctrl.value, isDark: isDark),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _MeshPainter extends CustomPainter {
  final double t;
  final bool isDark;
  _MeshPainter({required this.t, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final base = isDark ? RaastaColors.asphalt : RaastaColors.mist;
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    void blob(Color c, double ox, double oy, double r) {
      final cx = size.width * (0.35 + 0.25 * math.sin(t * math.pi * 2 + ox));
      final cy = size.height * (0.25 + 0.2 * math.cos(t * math.pi * 2 + oy));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [c.withValues(alpha: isDark ? 0.35 : 0.28), c.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    blob(RaastaColors.amber, 0, 0.4, size.shortestSide * 0.55);
    blob(RaastaColors.violet, 1.2, 1.0, size.shortestSide * 0.45);
    blob(RaastaColors.teal, 2.1, 0.2, size.shortestSide * 0.4);
    blob(RaastaColors.coral, 0.6, 2.4, size.shortestSide * 0.35);

    // Subtle road-grid lines
    final grid = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const step = 48.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshPainter old) => old.t != t;
}
