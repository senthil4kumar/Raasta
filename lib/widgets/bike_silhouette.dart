import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Hand-drawn (vector, original) side-on motorcycle silhouette, lit by a
/// spotlight from above. Drawn in a 1000 x 560 design space and scaled to fit.
class BikeSilhouette extends StatelessWidget {
  /// 0..1 reveal progress (a soft left-to-right wipe).
  final double reveal;
  const BikeSilhouette({super.key, this.reveal = 1});

  @override
  Widget build(BuildContext context) {
    Widget bike = AspectRatio(
      aspectRatio: 1000 / 560,
      child: CustomPaint(painter: _BikePainter()),
    );
    if (reveal < 1) {
      bike = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) {
          final edge = reveal * 1.35;
          return LinearGradient(
            colors: const [Colors.white, Colors.transparent],
            stops: [(edge - 0.35).clamp(0.0, 1.0), edge.clamp(0.0, 1.0)],
          ).createShader(rect);
        },
        child: bike,
      );
    }
    return Semantics(
      label: 'Motorcycle',
      image: true,
      child: Opacity(opacity: Curves.easeOut.transform(reveal), child: bike),
    );
  }
}

class _BikePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1000, size.height / 560);

    const rear = Offset(230, 400);
    const front = Offset(790, 400);

    // Floor shadow (a circle squashed into an ellipse for the gradient).
    canvas.save();
    canvas.translate(510, 522);
    canvas.scale(900 / 44, 1);
    canvas.drawCircle(
      Offset.zero,
      22,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xDD000000), Color(0x00000000)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 22)),
    );
    canvas.restore();

    Paint fill(Rect r, {Color top = const Color(0xFF2B2B2F)}) => Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, const Color(0xFF0C0C0E), const Color(0xFF050506)],
        stops: const [0, 0.5, 1],
      ).createShader(r);

    Paint rim(Rect r, {double a = 0.55}) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: a),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.45],
      ).createShader(r);

    void shape(Path p, {Color top = const Color(0xFF2B2B2F), double a = 0.55}) {
      final b = p.getBounds();
      canvas.drawPath(p, fill(b, top: top));
      canvas.drawPath(p, rim(b, a: a));
    }

    void line(Offset a, Offset b, double w, {Color c = const Color(0xFF1A1A1D)}) {
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = c
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        a.translate(0, -w / 2 + 1),
        b.translate(0, -w / 2 + 1),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round,
      );
    }

    void wheel(Offset c, {bool disc = false}) {
      // Tyre.
      canvas.drawCircle(
        c,
        105,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 32
          ..color = const Color(0xFF0D0D0F),
      );
      canvas.drawCircle(
        c,
        121,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.5),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0, 0.5],
          ).createShader(Rect.fromCircle(center: c, radius: 121)),
      );
      // Rim.
      canvas.drawCircle(
        c,
        86,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = const Color(0xFF3B3B40),
      );
      // Spokes.
      final sp = Paint()
        ..color = const Color(0xFF2A2A2E)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        canvas.drawLine(
          c + Offset(math.cos(a), math.sin(a)) * 16,
          c + Offset(math.cos(a), math.sin(a)) * 84,
          sp,
        );
      }
      if (disc) {
        canvas.drawCircle(
          c,
          52,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFF55555B),
        );
      }
      canvas.drawCircle(c, 15, Paint()..color = const Color(0xFF242427));
      canvas.drawCircle(
        c,
        15,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.35),
      );
    }

    wheel(rear);
    wheel(front, disc: true);

    // Swingarm and shock.
    line(const Offset(405, 372), rear, 17);
    line(const Offset(372, 330), const Offset(318, 388), 9,
        c: const Color(0xFF222226));

    // Exhaust, running low and long to the tail.
    final exhaust = Path()
      ..moveTo(470, 436)
      ..cubicTo(400, 458, 300, 450, 178, 408)
      ..lineTo(172, 388)
      ..cubicTo(300, 422, 400, 424, 468, 410)
      ..close();
    shape(exhaust, top: const Color(0xFF45454B), a: 0.7);

    // Engine block with cooling fins.
    final engine = Path()
      ..moveTo(430, 352)
      ..lineTo(604, 338)
      ..lineTo(650, 396)
      ..lineTo(596, 444)
      ..lineTo(448, 446)
      ..close();
    shape(engine, top: const Color(0xFF303035), a: 0.5);
    final fin = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1.2;
    for (var y = 362.0; y < 436; y += 11) {
      canvas.drawLine(Offset(452, y), Offset(626, y - 4), fin);
    }

    // Front fork and fender.
    line(const Offset(706, 252), front, 13, c: const Color(0xFF202024));
    line(const Offset(694, 256), front.translate(-9, 0), 7,
        c: const Color(0xFF131316));
    canvas.drawArc(
      Rect.fromCircle(center: front, radius: 136),
      -2.45,
      1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF17171A),
    );
    canvas.drawArc(
      Rect.fromCircle(center: front, radius: 142),
      -2.45,
      1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // Tail and seat.
    final tail = Path()
      ..moveTo(150, 336)
      ..cubicTo(210, 304, 330, 296, 452, 302)
      ..lineTo(470, 348)
      ..cubicTo(380, 346, 270, 352, 168, 354)
      ..close();
    shape(tail, top: const Color(0xFF34343A), a: 0.65);

    // Fuel tank.
    final tank = Path()
      ..moveTo(430, 304)
      ..cubicTo(480, 246, 600, 214, 690, 238)
      ..cubicTo(728, 250, 730, 288, 704, 308)
      ..cubicTo(650, 338, 540, 352, 462, 346)
      ..close();
    shape(tank, top: const Color(0xFF4A4A51), a: 0.85);

    // Small cowl and headlight.
    final cowl = Path()
      ..moveTo(700, 248)
      ..cubicTo(722, 208, 756, 208, 776, 238)
      ..lineTo(742, 276)
      ..close();
    shape(cowl, top: const Color(0xFF3A3A40), a: 0.7);
    canvas.drawCircle(
      const Offset(742, 262),
      34,
      Paint()
        ..color = const Color(0xFFFFF1D6).withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(742, 266), width: 36, height: 44),
      Paint()..color = const Color(0xFF131316),
    );
    canvas.drawCircle(
      const Offset(748, 266),
      11,
      Paint()..color = const Color(0xFFF3E7CC).withValues(alpha: 0.9),
    );

    // Handlebar.
    line(const Offset(688, 238), const Offset(668, 200), 9);
    line(const Offset(668, 200), const Offset(614, 192), 8);

    // Amber tail-light: the single touch of accent.
    canvas.drawCircle(
      const Offset(156, 338),
      16,
      Paint()
        ..color = RaastaColors.amber.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      const Offset(156, 338),
      3.5,
      Paint()..color = RaastaColors.amberLight,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BikePainter old) => false;
}
