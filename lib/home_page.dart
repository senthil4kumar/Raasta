import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'group_service.dart';
import 'map_page.dart';

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
          MaterialPageRoute(
            builder: (_) =>
                MapPage(service: widget.service, code: code, name: name),
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
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.two_wheeler,
                      size: 46,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Hogona',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ride together. See each other. Talk.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (widget.service.isDemo) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: scheme.secondaryContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Demo mode: Firebase is not set up, so two simulated '
                        'riders will appear around you.',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  onPressed: _busy
                      ? null
                      : () => _run((n) => widget.service.createGroup(n)),
                  icon: const Icon(Icons.add),
                  label: const Text('Start a new group'),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or join your friends',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
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
                        style: const TextStyle(fontSize: 22, letterSpacing: 8),
                        decoration: const InputDecoration(
                          labelText: '4-digit group code',
                          prefixIcon: Icon(Icons.pin_outlined),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 58,
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run((n) async {
                                final code = _code.text.trim();
                                final ok = await widget.service.joinGroup(
                                  code,
                                  n,
                                );
                                return ok ? code : null;
                              }),
                        child: const Text('Join'),
                      ),
                    ),
                  ],
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
