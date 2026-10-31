import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'group_service.dart';
import 'map_page.dart';
import 'theme/app_theme.dart';
import 'widgets/glass_surface.dart';
import 'widgets/mesh_background.dart';
import 'widgets/pressable_scale.dart';
import 'widgets/stagger_reveal.dart' show revealStagger;

class HomePage extends StatefulWidget {
  final GroupService service;
  const HomePage({super.key, required this.service});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  Future<void> _run(Future<String?> Function(String name) action) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Enter your name first');
      return;
    }
    setState(() => _busy = true);
    try {
      final code = await action(name);
      if (!mounted) return;
      if (code == null) {
        _snack('No group with that code');
      } else {
        await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                MapPage(service: widget.service, code: code, name: name),
            transitionsBuilder: (context, animation, secondary, child) {
              final curve = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              if (MediaQuery.disableAnimationsOf(context)) return child;
              return FadeTransition(
                opacity: curve,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(curve),
                  child: child,
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      _snack('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: MeshBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  revealStagger(context, _HeroHeader(isDark: isDark), index: 0),
                  const SizedBox(height: 28),
                  revealStagger(
                    context,
                    GlassSurface(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.service.isDemo) ...[
                            revealStagger(
                              context,
                              _DemoBanner(scheme: scheme),
                              index: 1,
                            ),
                            const SizedBox(height: 20),
                          ],
                          revealStagger(
                            context,
                            TextField(
                              controller: _name,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Your name',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                            ),
                            index: 2,
                          ),
                          const SizedBox(height: 18),
                          revealStagger(
                            context,
                            PressableScale(
                              onTap: _busy
                                  ? null
                                  : () => _run(
                                      (n) => widget.service.createGroup(n),
                                    ),
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  backgroundColor: scheme.primary,
                                  foregroundColor: scheme.onPrimary,
                                ),
                                onPressed: _busy
                                    ? null
                                    : () => _run(
                                        (n) => widget.service.createGroup(n),
                                      ),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Start a new group'),
                              ),
                            ),
                            index: 3,
                          ),
                          const SizedBox(height: 28),
                          revealStagger(
                            context,
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: scheme.outline.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'or join your friends',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: scheme.outline.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            index: 4,
                          ),
                          const SizedBox(height: 22),
                          revealStagger(
                            context,
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _code,
                                    keyboardType: TextInputType.number,
                                    maxLength: 4,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: const TextStyle(
                                      fontSize: 22,
                                      letterSpacing: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      labelText: '4-digit group code',
                                      prefixIcon: Icon(Icons.pin_outlined),
                                      counterText: '',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                PressableScale(
                                  onTap: _busy
                                      ? null
                                      : () => _run((n) async {
                                          final code = _code.text.trim();
                                          final ok = await widget.service
                                              .joinGroup(code, n);
                                          return ok ? code : null;
                                        }),
                                  child: SizedBox(
                                    height: 58,
                                    child: OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _run((n) async {
                                              final code = _code.text.trim();
                                              final ok = await widget.service
                                                  .joinGroup(code, n);
                                              return ok ? code : null;
                                            }),
                                      child: const Text('Join'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            index: 5,
                          ),
                          if (_busy) ...[
                            const SizedBox(height: 24),
                            Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    index: 1,
                  ),
                  const SizedBox(height: 24),
                  revealStagger(context, _FeatureRow(scheme: scheme), index: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final bool isDark;
  const _HeroHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final logo = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, RaastaColors.coral.withValues(alpha: 0.9)],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(
        Icons.two_wheeler_rounded,
        size: 48,
        color: Colors.white,
      ),
    );

    Widget heroLogo = logo;
    if (motionEnabled(context)) {
      heroLogo = logo
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.04, 1.04),
            duration: 2.8.seconds,
            curve: Curves.easeInOut,
          )
          .then()
          .shimmer(
            duration: 1.2.seconds,
            color: Colors.white.withValues(alpha: 0.25),
          );
    }

    return Column(
      children: [
        heroLogo,
        const SizedBox(height: 20),
        Text(
          'Raasta',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Ride together. See each other. Talk.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _DemoBanner extends StatelessWidget {
  final ColorScheme scheme;
  const _DemoBanner({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            scheme.secondary.withValues(alpha: 0.15),
            scheme.tertiary.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: scheme.secondary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Demo mode: Firebase is not set up, so two simulated '
              'riders will appear around you.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final ColorScheme scheme;
  const _FeatureRow({required this.scheme});

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String label) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: scheme.primary),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(Icons.map_rounded, 'Live map'),
        const SizedBox(width: 10),
        chip(Icons.mic_rounded, 'Push-to-talk'),
        const SizedBox(width: 10),
        chip(Icons.route_rounded, 'Group routes'),
      ],
    );
  }
}
