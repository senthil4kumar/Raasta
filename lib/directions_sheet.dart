import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'routing.dart';

class RoutePick {
  final Place start;
  final Place dest;
  const RoutePick(this.start, this.dest);
}

/// Bottom sheet to choose a start and destination. Start defaults to the
/// rider's own location.
class DirectionsSheet extends StatefulWidget {
  final LatLng? me;
  const DirectionsSheet({super.key, required this.me});

  @override
  State<DirectionsSheet> createState() => _DirectionsSheetState();
}

class _DirectionsSheetState extends State<DirectionsSheet> {
  final _startCtl = TextEditingController();
  final _destCtl = TextEditingController();
  Place? _start;
  Place? _dest;
  bool _editingStart = false;
  List<Place> _results = const [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.me != null) {
      _start = Place('Your location', widget.me!);
      _startCtl.text = 'Your location';
    }
  }

  void _onChanged(String text, bool forStart) {
    _editingStart = forStart;
    if (forStart) {
      _start = null;
    } else {
      _dest = null;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _searching = true);
      try {
        final r = await searchPlaces(text, near: widget.me);
        if (mounted) setState(() => _results = r);
      } catch (_) {
        if (mounted) setState(() => _results = const []);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
    setState(() {});
  }

  void _choose(Place p) {
    setState(() {
      if (_editingStart) {
        _start = p;
        _startCtl.text = p.name;
      } else {
        _dest = p;
        _destCtl.text = p.name;
      }
      _results = const [];
    });
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _startCtl.dispose();
    _destCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _start != null && _dest != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plan a ride', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _startCtl,
            onTap: () => _editingStart = true,
            onChanged: (t) => _onChanged(t, true),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.trip_origin,
                color: Color(0xFF1A73E8),
              ),
              labelText: 'Start',
              border: const OutlineInputBorder(),
              suffixIcon: widget.me == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.my_location),
                      tooltip: 'Use my location',
                      onPressed: () =>
                          _choose(Place('Your location', widget.me!)),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _destCtl,
            autofocus: true,
            onTap: () => _editingStart = false,
            onChanged: (t) => _onChanged(t, false),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.place, color: Color(0xFFD93025)),
              labelText: 'Destination',
              border: OutlineInputBorder(),
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in _results)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(p.name),
                    onTap: () => _choose(p),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: ready
                ? () => Navigator.pop(context, RoutePick(_start!, _dest!))
                : null,
            icon: const Icon(Icons.directions),
            label: const Text('Show route to the whole group'),
          ),
        ],
      ),
    );
  }
}
