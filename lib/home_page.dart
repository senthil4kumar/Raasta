import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'group_service.dart';
import 'map_page.dart';
import 'theme/app_theme.dart';
import 'widgets/luxe_backdrop.dart';
import 'widgets/luxe_controls.dart';
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

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: RaastaColors.muted,
        height: 1.5,
        letterSpacing: 0.4,
      ),
    ),
  );

  Widget _startTab() {
    return Column(
      key: const ValueKey('start'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hint(
          'You are the Ride Captain. Start a ride and share the code with your riders.',
        ),
        const SizedBox(height: 8),
        FocusUnderline(
          child: TextField(
            controller: _captain,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _start(),
            decoration: const InputDecoration(labelText: 'Ride Captain name'),
          ),
        ),
        const SizedBox(height: 30),
        LuxeButton(
          label: 'Start the ride',
          onPressed: _busy ? null : _start,
        ),
      ],
    );
  }

  Widget _joinTab() {
    return Column(
      key: const ValueKey('join'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hint('Ask your Ride Captain for the 4-digit code.'),
        const SizedBox(height: 8),
        FocusUnderline(
          child: TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
        ),
        const SizedBox(height: 10),
        FocusUnderline(
          child: TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _join(),
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 14,
              fontWeight: FontWeight.w300,
            ),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'Ride code',
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 30),
        LuxeButton(label: 'Join the ride', onPressed: _busy ? null : _join),
      ],
    );
  }

  Widget _form(BuildContext context, {required bool centered}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: LuxeWordmark(text: 'RAASTA', size: centered ? 30 : 38),
        ),
        const SizedBox(height: 12),
        revealStagger(
          context,
          Text(
            'Ride together. See each other. Talk.',
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: RaastaColors.muted,
              letterSpacing: 0.8,
            ),
          ),
          index: 4,
        ),
        const SizedBox(height: 26),
        revealStagger(context, const _GrowingHairline(), index: 5),
        const SizedBox(height: 26),
        if (widget.service.isDemo) ...[
          revealStagger(context, const _DemoBanner(), index: 5),
          const SizedBox(height: 20),
        ],
        revealStagger(
          context,
          LuxeToggle(
            index: _tab,
            labels: const ['Start a ride', 'Join a ride'],
            onChanged: (i) => setState(() => _tab = i),
          ),
          index: 6,
        ),
        const SizedBox(height: 22),
        revealStagger(
          context,
          AnimatedSize(
            duration: motionDuration(context, const Duration(milliseconds: 260)),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: motionDuration(context, const Duration(milliseconds: 280)),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.03, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _tab == 0 ? _startTab() : _joinTab(),
            ),
          ),
          index: 7,
        ),
        if (_busy) ...[
          const SizedBox(height: 22),
          const LinearProgressIndicator(minHeight: 1),
        ],
        const SizedBox(height: 40),
        revealStagger(context, const _FeatureRow(), index: 9),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: LuxeBackdrop(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 860;
            if (wide) {
              return Row(
                children: [
                  const Expanded(flex: 11, child: BikeHero()),
                  Expanded(
                    flex: 9,
                    child: SafeArea(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 32, 64, 32),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: _form(context, centered: false),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            final heroH = (c.maxHeight * 0.34).clamp(190.0, 340.0);
            return SafeArea(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        SizedBox(
                          height: heroH,
                          child: ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (r) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white, Colors.white, Colors.transparent],
                              stops: [0, 0.78, 1],
                            ).createShader(r),
                            child: const BikeHero(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
                          child: _form(context, centered: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Hairline divider that draws itself in from the left.
class _GrowingHairline extends StatelessWidget {
  const _GrowingHairline();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: motionEnabled(context) ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: t,
          child: Container(height: 0.7, color: RaastaColors.hairline),
        ),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: RaastaColors.hairline, width: 0.7),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_outlined,
              color: RaastaColors.amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Demo mode: Firebase is not set up, so two simulated '
              'riders will appear around you.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: RaastaColors.muted,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three tiny hairline-separated labels.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    Widget label(IconData icon, String text) => Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: RaastaColors.muted),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: RaastaColors.muted,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
    Widget sep() => Container(width: 0.7, height: 34, color: RaastaColors.hairline);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        label(Icons.map_outlined, 'Live map'),
        sep(),
        label(Icons.mic_none_rounded, 'Push-to-talk'),
        sep(),
        label(Icons.route_outlined, 'Group routes'),
      ],
    );
  }
}
