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
  final _captain = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  /// 0 = start a ride, 1 = join a ride.
  int _tab = 0;

  @override
  void dispose() {
    _captain.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(
    TextEditingController nameField,
    String missingName,
    Future<String?> Function(String name) action,
  ) async {
    final name = nameField.text.trim();
    if (name.isEmpty) {
      _snack(missingName);
      return;
    }
    setState(() => _busy = true);
    try {
      final code = await action(name);
      if (!mounted) return;
      if (code == null) {
        _snack('No ride found with that code. Check the code and try again.');
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

  void _start() => _run(
    _captain,
    'Enter the Ride Captain name first',
    (n) => widget.service.createGroup(n),
  );

  void _join() {
    final code = _code.text.trim();
    if (code.length != 4) {
      _snack('Enter the 4-digit ride code');
      return;
    }
    _run(_name, 'Enter your name first', (n) async {
      final ok = await widget.service.joinGroup(code, n);
      return ok ? code : null;
    });
  }

  Widget _startTab(ColorScheme scheme) {
    return Column(
      key: const ValueKey('start'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'You are the Ride Captain. Start a ride and share the code with your riders.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _captain,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _start(),
          decoration: const InputDecoration(
            labelText: 'Ride Captain name',
            prefixIcon: Icon(Icons.sports_motorsports_rounded),
          ),
        ),
        const SizedBox(height: 20),
        PressableScale(
          onTap: _busy ? null : _start,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
            onPressed: _busy ? null : _start,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start the ride'),
          ),
        ),
      ],
    );
  }

  Widget _joinTab(ColorScheme scheme) {
    return Column(
      key: const ValueKey('join'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ask your Ride Captain for the 4-digit code.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Your name',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _join(),
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 12,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            labelText: 'Ride code',
            prefixIcon: Icon(Icons.pin_outlined),
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        PressableScale(
          onTap: _busy ? null : _join,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
            onPressed: _busy ? null : _join,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Join the ride'),
          ),
        ),
      ],
    );
  }

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
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.service.isDemo) ...[
                            _DemoBanner(scheme: scheme),
                            const SizedBox(height: 16),
                          ],
                          _TabSwitch(
                            index: _tab,
                            labels: const ['Start a ride', 'Join a ride'],
                            icons: const [
                              Icons.flag_rounded,
                              Icons.group_add_rounded,
                            ],
                            onChanged: (i) => setState(() => _tab = i),
                          ),
                          const SizedBox(height: 22),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                            child: _tab == 0
                                ? _startTab(scheme)
                                : _joinTab(scheme),
                          ),
                          if (_busy) ...[
                            const SizedBox(height: 20),
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

class _TabSwitch extends StatelessWidget {
  final int index;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onChanged;
  const _TabSwitch({
    required this.index,
    required this.labels,
    required this.icons,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: index == i ? scheme.primary : Colors.transparent,
                    boxShadow: index == i
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icons[i],
                        size: 19,
                        color: index == i
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: index == i
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
