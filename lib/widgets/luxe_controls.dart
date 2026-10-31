import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Thin, wide-tracked wordmark whose letters track in one after another.
class LuxeWordmark extends StatelessWidget {
  final String text;
  final double size;
  const LuxeWordmark({super.key, required this.text, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineLarge?.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w200,
      letterSpacing: 0,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final letters = text.split('');
    final animate = motionEnabled(context);
    return Semantics(
      header: true,
      label: text,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < letters.length; i++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: animate ? 0 : 1, end: 1),
                duration: Duration(milliseconds: animate ? 900 + i * 110 : 0),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Padding(
                    // Tracking settles from very wide to the final spacing.
                    padding: EdgeInsets.only(right: size * (0.16 + 0.6 * (1 - t))),
                    child: child,
                  ),
                ),
                child: Text(letters[i], style: style),
              ),
          ],
        ),
      ),
    );
  }
}

/// Draws an amber line that grows from the centre under a field when focused.
class FocusUnderline extends StatefulWidget {
  final Widget child;
  const FocusUnderline({super.key, required this.child});

  @override
  State<FocusUnderline> createState() => _FocusUnderlineState();
}

class _FocusUnderlineState extends State<FocusUnderline> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Stack(
        children: [
          widget.child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _focused ? 1 : 0),
                duration: motionDuration(
                  context,
                  const Duration(milliseconds: 380),
                ),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => Align(
                  child: FractionallySizedBox(
                    widthFactor: t,
                    child: Container(
                      height: 1.4,
                      color: RaastaColors.amber.withValues(alpha: t),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin-outline two-segment toggle with an indicator that slides.
class LuxeToggle extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  const LuxeToggle({
    super.key,
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dur = motionDuration(context, const Duration(milliseconds: 320));
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x40FFFFFF), width: 0.8),
        borderRadius: BorderRadius.circular(3),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: dur,
                curve: Curves.easeOutCubic,
                left: index * w,
                top: 0,
                bottom: 0,
                width: w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    border: const Border(
                      bottom: BorderSide(color: RaastaColors.amber, width: 1.4),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: index == i,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(i),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: dur,
                              style: Theme.of(context).textTheme.labelLarge!
                                  .copyWith(
                                    letterSpacing: 1.2,
                                    color: index == i
                                        ? scheme.onSurface
                                        : scheme.onSurfaceVariant,
                                  ),
                              child: Text(labels[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The single amber call to action, with a slow sheen on hover and press.
class LuxeButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const LuxeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_right_alt_rounded,
  });

  @override
  State<LuxeButton> createState() => _LuxeButtonState();
}

class _LuxeButtonState extends State<LuxeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _down = false;

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  void _play() {
    if (motionEnabled(context) && !_sheen.isAnimating) {
      _sheen.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => enabled ? _play() : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled
            ? (_) {
                setState(() => _down = true);
                _play();
              }
            : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: widget.label,
          child: ExcludeSemantics(
            child: AnimatedScale(
              scale: _down ? 0.985 : 1,
              duration: motionDuration(context, const Duration(milliseconds: 120)),
              child: AnimatedOpacity(
                opacity: enabled ? 1 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(
                    children: [
                      Container(
                        height: 56,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE0A050), RaastaColors.amberDeep],
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.label,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: scheme.onPrimary,
                                    fontSize: 16,
                                    letterSpacing: 1.6,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(width: 10),
                            Icon(widget.icon, size: 24, color: scheme.onPrimary),
                          ],
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _sheen,
                            builder: (context, _) => Align(
                              alignment: Alignment(-2.5 + 5.7 * _sheen.value, 0),
                              child: FractionallySizedBox(
                                widthFactor: 0.4,
                                child: Transform(
                                  transform: Matrix4.skewX(-0.45),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0),
                                          Colors.white.withValues(
                                            alpha: _sheen.isAnimating ? 0.28 : 0,
                                          ),
                                          Colors.white.withValues(alpha: 0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Expanding rings that pulse around the push-to-talk button while held.
class TalkPulse extends StatefulWidget {
  final bool active;
  final Color color;
  final double size;
  final Widget child;
  const TalkPulse({
    super.key,
    required this.active,
    required this.color,
    required this.size,
    required this.child,
  });

  @override
  State<TalkPulse> createState() => _TalkPulseState();
}

class _TalkPulseState extends State<TalkPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didUpdateWidget(covariant TalkPulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    final run = widget.active && ambientMotionEnabled(context);
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.size * 1.9;
    // Layout size stays the button size; the rings overflow it harmlessly.
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (widget.active)
            Positioned(
              left: (widget.size - box) / 2,
              top: (widget.size - box) / 2,
              width: box,
              height: box,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => CustomPaint(
                    painter: _RingPainter(
                      t: _c.value,
                      color: widget.color,
                      base: widget.size / 2,
                    ),
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t;
  final Color color;
  final double base;
  const _RingPainter({required this.t, required this.color, required this.base});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      final r = base + (maxR - base) * Curves.easeOut.transform(p);
      canvas.drawCircle(
        c,
        math.max(r, base),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: 0.55 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.t != t;
}
