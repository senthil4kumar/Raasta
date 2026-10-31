import 'dart:ui';

import 'package:flutter/material.dart';

/// Dark translucent glass with a hairline border. Reads clearly over both the
/// black home screen and a light OpenStreetMap tile.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final Color? tint;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.blur = 18,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final fill = tint ?? const Color(0xFF0B0B0D).withValues(alpha: 0.74);
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: borderRadius,
            border: Border.all(color: const Color(0x2EFFFFFF), width: 0.7),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 22,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
