import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'bike_silhouette.dart';

/// Matte black background with a very soft film grain.
class LuxeBackdrop extends StatelessWidget {
  final Widget child;
  const LuxeBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: RaastaColors.asphalt,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          const IgnorePointer(
            child: RepaintBoundary(child: CustomPaint(painter: _GrainPainter())),
          ),
        ],
      ),
    );
  }
}

/// Static film grain: a fixed scatter of faint specks (painted once).
class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final n = (size.width * size.height / 700).clamp(400, 3200).toInt();
    final pts = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
    ];
    canvas.drawPoints(
      PointMode.points,
      pts,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..strokeWidth = 1.2,
    );
    final dark = <Offset>[
      for (var i = 0; i < n ~/ 2; i++)
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
    ];
    canvas.drawPoints(
      PointMode.points,
      dark,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Spotlit motorcycle: spotlight fades up, the bike is revealed, the light
/// slowly drifts, and (on desktop) the pointer adds a gentle parallax.
class BikeHero extends StatefulWidget {
  const BikeHero({super.key});

  @override
  State<BikeHero> createState() => _BikeHeroState();
}

class _BikeHeroState extends State<BikeHero> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  );
  Offset _pointer = Offset.zero;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionEnabled(context)) {
      _intro.forward();
    } else {
      _intro.value = 1;
    }
    if (ambientMotionEnabled(context)) _drift.repeat();
  }

  @override
  void dispose() {
    _intro.dispose();
    _drift.dispose();
    super.dispose();
  }

  void _onHover(PointerEvent e, Size size) {
    if (!motionEnabled(context)) return;
    final dx = (e.localPosition.dx / size.width - 0.5) * 2;
    final dy = (e.localPosition.dy / size.height - 0.5) * 2;
    setState(() => _pointer = Offset(dx.clamp(-1, 1), dy.clamp(-1, 1)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return MouseRegion(
          onHover: (e) => _onHover(e, size),
          onExit: (_) => setState(() => _pointer = Offset.zero),
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(begin: Offset.zero, end: _pointer),
            duration: motionDuration(context, const Duration(milliseconds: 700)),
            curve: Curves.easeOutCubic,
            builder: (context, p, _) => AnimatedBuilder(
              animation: Listenable.merge([_intro, _drift]),
              builder: (context, _) {
                final light = Curves.easeOut.transform(
                  (_intro.value / 0.55).clamp(0.0, 1.0),
                );
                final bikeT = Curves.easeInOutCubic.transform(
                  ((_intro.value - 0.25) / 0.75).clamp(0.0, 1.0),
                );
                final t = _drift.value * math.pi * 2;
                final drift = Offset(math.sin(t) * 0.12, math.cos(t) * 0.05);
                return ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, 0.8, 1],
                  ).createShader(r),
                  child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Spotlight.
                    CustomPaint(
                      painter: _SpotPainter(
                        strength: light,
                        center: Offset(
                          0.46 + drift.dx - p.dx * 0.05,
                          0.42 + drift.dy - p.dy * 0.03,
                        ),
                      ),
                    ),
                    // Bike.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Align(
                        alignment: const Alignment(0, 0.18),
                        child: Transform.translate(
                          offset: Offset(p.dx * -12, p.dy * -6),
                          child: BikeSilhouette(reveal: bikeT),
                        ),
                      ),
                    ),
                  ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _SpotPainter extends CustomPainter {
  final double strength;
  final Offset center;
  const _SpotPainter({required this.strength, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * center.dx, size.height * center.dy);
    final r = size.longestSide * 0.75;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(255, 244, 225, 0.20 * strength),
            Color.fromRGBO(255, 244, 225, 0.07 * strength),
            const Color(0x00000000),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
    // Faint light pool on the floor (a circle squashed into an ellipse, since
    // radial gradients are sized by their shortest side).
    final fw = size.width * 0.95;
    final fh = size.height * 0.16;
    canvas.save();
    canvas.translate(size.width * 0.5, size.height * 0.80);
    canvas.scale(fw / fh, 1);
    canvas.drawCircle(
      Offset.zero,
      fh / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(255, 244, 225, 0.10 * strength),
            const Color(0x00000000),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: fh / 2)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpotPainter old) =>
      old.strength != strength || old.center != center;
}
