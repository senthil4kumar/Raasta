import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Micro-interaction: subtle scale on press without layout jank.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final duration = motionDuration(context, const Duration(milliseconds: 120));
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _down = false);
              widget.onTap?.call();
            },
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
