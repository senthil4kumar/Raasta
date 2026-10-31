import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart' as fa;

import '../theme/app_theme.dart';

Widget revealStagger(BuildContext context, Widget child, {required int index}) {
  if (!motionEnabled(context)) return child;
  return fa.Animate(
    delay: Duration(milliseconds: 80 * index),
    effects: [
      fa.FadeEffect(
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      ),
      fa.SlideEffect(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      ),
    ],
    child: child,
  );
}
