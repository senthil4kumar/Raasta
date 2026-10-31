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

  Future<void> _run(Future<String?> Function() action) async {
    if (_name.text.trim().isEmpty) {
      _snack('Enter your name first');
      return;
    }
    setState(() => _busy = true);
    try {
      final code = await action();
      if (!mounted) return;
      if (code == null) {
        _snack('No group with that code');
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MapPage(
              service: widget.service,
              code: code,
              name: _name.text.trim(),
            ),
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
    final name = _name.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Air')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            if (widget.service.isDemo)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Demo mode: Firebase is not set up, so two '
                    'simulated riders will appear around you.',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => widget.service.createGroup(
                        name.isEmpty ? _name.text.trim() : name,
                      ),
                    ),
              child: const Text('Create group'),
            ),
            const Divider(height: 48),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Group code'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final code = _code.text.trim().toUpperCase();
                      final ok = await widget.service.joinGroup(
                        code,
                        _name.text.trim(),
                      );
                      return ok ? code : null;
                    }),
              child: const Text('Join group'),
            ),
          ],
        ),
      ),
    );
  }
}
