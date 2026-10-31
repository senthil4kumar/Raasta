import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';

import 'routing.dart';
import 'theme/app_theme.dart';
import 'widgets/glass_surface.dart';

class RoutePick {
  final Place start;
  final Place dest;

  /// True: everyone in the ride sees the route. False: only this rider.
  final bool shared;
  const RoutePick(this.start, this.dest, {required this.shared});
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: scheme.outline.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Text('Plan a ride', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Pick a route for everyone in your group',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _startCtl,
            onTap: () => _editingStart = true,
            onChanged: (t) => _onChanged(t, true),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.trip_origin_rounded,
                color: scheme.primary,
              ),
              labelText: 'Start',
              suffixIcon: widget.me == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.my_location_rounded),
                      tooltip: 'Use my location',
                      onPressed: () =>
                          _choose(Place('Your location', widget.me!)),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destCtl,
            autofocus: true,
            onTap: () => _editingStart = false,
            onChanged: (t) => _onChanged(t, false),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.place_rounded, color: scheme.error),
              labelText: 'Destination',
            ),
          ),
          if (_searching)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(4),
                color: scheme.primary,
                backgroundColor: scheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < _results.length; i++)
                  _ResultTile(
                        place: _results[i],
                        onTap: () => _choose(_results[i]),
                      )
                      .animate(autoPlay: motionEnabled(context))
                      .fadeIn(duration: 280.ms, delay: (40 * i).ms)
                      .slideX(begin: 0.04, end: 0),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: ready
                ? () => Navigator.pop(
                    context,
                    RoutePick(_start!, _dest!, shared: true),
                  )
                : null,
            icon: const Icon(Icons.groups_rounded),
            label: const Text('Share with the whole group'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: ready
                ? () => Navigator.pop(
                    context,
                    RoutePick(_start!, _dest!, shared: false),
                  )
                : null,
            icon: const Icon(Icons.person_rounded),
            label: const Text('Just for me'),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;
  const _ResultTile({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: GlassSurface(
        padding: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(12),
        blur: 8,
        child: Icon(
          Icons.location_on_outlined,
          color: scheme.primary,
          size: 20,
        ),
      ),
      title: Text(place.name),
      onTap: onTap,
    );
  }
}
