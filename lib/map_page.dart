import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'group_service.dart';
import 'rider.dart';

class MapPage extends StatefulWidget {
  final GroupService service;
  final String code;
  final String name;
  const MapPage(
      {super.key,
      required this.service,
      required this.code,
      required this.name});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _map = MapController();
  final _focus = FocusNode();
  StreamSubscription<Position>? _gps;
  LatLng? _me;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startLocation();
  }

  Future<void> _startLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      setState(() => _error = 'Location permission is needed to show you on the map.');
      return;
    }
    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((p) {
      final here = LatLng(p.latitude, p.longitude);
      final first = _me == null;
      setState(() => _me = here);
      widget.service.updateLocation(here);
      if (first) _map.move(here, 15);
    });
  }

  // Handlebar remote: a Bluetooth remote that acts as a keyboard arrives here.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final cam = _map.camera;
    final k = event.logicalKey;
    // Pan distance shrinks as you zoom in.
    final step = 120.0;
    void pan(double dx, double dy) {
      final c = cam.projectAtZoom(cam.center) + Offset(dx, dy);
      _map.move(cam.unprojectAtZoom(c), cam.zoom);
    }

    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.equal ||
        k == LogicalKeyboardKey.add || k == LogicalKeyboardKey.numpadAdd) {
      _map.move(cam.center, (cam.zoom + 1).clamp(3, 19));
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.minus ||
        k == LogicalKeyboardKey.numpadSubtract) {
      _map.move(cam.center, (cam.zoom - 1).clamp(3, 19));
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      pan(-step, 0);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      pan(step, 0);
    } else if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.select) {
      _recenter();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _zoom(double d) {
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + d).clamp(3, 19));
  }

  void _recenter() {
    final me = _me;
    if (me != null) _map.move(me, _map.camera.zoom);
  }

  @override
  void dispose() {
    _gps?.cancel();
    _focus.dispose();
    widget.service.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group ${widget.code}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy code',
            onPressed: () => Clipboard.setData(ClipboardData(text: widget.code)),
          ),
        ],
      ),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(children: [
          StreamBuilder<List<Rider>>(
            stream: widget.service.riders(),
            builder: (context, snap) {
              final riders = snap.data ?? const <Rider>[];
              return FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: const LatLng(20.5937, 78.9629),
                  initialZoom: 4,
                  onTap: (_, _) => _focus.requestFocus(),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.air.air_rider',
                  ),
                  MarkerLayer(markers: [
                    for (final r in riders)
                      Marker(
                        point: r.position,
                        width: 90,
                        height: 60,
                        child: _RiderPin(
                            name: r.name, isMe: r.id == widget.service.myId),
                      ),
                  ]),
                ],
              );
            },
          ),
          if (_error != null)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12), child: Text(_error!))),
            ),
        ]),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
              heroTag: 'in',
              onPressed: () => _zoom(1),
              child: const Icon(Icons.add)),
          const SizedBox(height: 8),
          FloatingActionButton.small(
              heroTag: 'out',
              onPressed: () => _zoom(-1),
              child: const Icon(Icons.remove)),
          const SizedBox(height: 8),
          FloatingActionButton(
              heroTag: 'me',
              onPressed: _recenter,
              child: const Icon(Icons.my_location)),
        ],
      ),
    );
  }
}

class _RiderPin extends StatelessWidget {
  final String name;
  final bool isMe;
  const _RiderPin({required this.name, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final color = isMe ? Colors.lightBlueAccent : Colors.deepOrange;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.black87, borderRadius: BorderRadius.circular(8)),
        child: Text(name,
            style: const TextStyle(fontSize: 11, color: Colors.white),
            overflow: TextOverflow.ellipsis),
      ),
      Icon(Icons.two_wheeler, color: color, size: 30),
    ]);
  }
}
