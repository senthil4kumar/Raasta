import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'group_service.dart';
import 'rider.dart';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'voice.dart';

class MapPage extends StatefulWidget {
  final GroupService service;
  final String code;
  final String name;
  const MapPage({
    super.key,
    required this.service,
    required this.code,
    required this.name,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _map = MapController();
  final _focus = FocusNode();
  StreamSubscription<Position>? _gps;
  Timer? _beat;
  late final VoiceController _voice = VoiceController(widget.service);
  StreamSubscription<List<Rider>>? _ridersSub;
  LatLng? _me;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startLocation();
    _ridersSub = widget.service.riders().listen((r) {
      _latest = r;
      _voice.updatePeers(r);
    });
  }

  void _onPosition(Position p) {
    final here = LatLng(p.latitude, p.longitude);
    final first = _me == null;
    setState(() {
      _me = here;
      _error = null;
    });
    widget.service.updateLocation(here);
    if (first) _map.move(here, 15);
  }

  Future<void> _startLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(
          () => _error =
              'Location Services are off. Turn them on in phone Settings.',
        );
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(
          () => _error =
              'Location is blocked. On iPhone: Settings > Privacy > Location '
              'Services > Safari Websites > While Using the App.',
        );
        return;
      }
      setState(() => _error = 'Finding your location...');
      // Ask once for a quick first fix, then keep following.
      try {
        _onPosition(
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 20),
            ),
          ),
        );
      } catch (_) {}
      _gps =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen(
            _onPosition,
            onError: (e) => setState(() => _error = 'Location error: $e'),
          );
      // Repeat the last fix so friends still see you while standing still.
      _beat = Timer.periodic(const Duration(seconds: 15), (_) {
        final me = _me;
        if (me != null) widget.service.updateLocation(me);
      });
    } catch (e) {
      setState(() => _error = 'Location error: $e');
    }
  }

  // Handlebar remote: a Bluetooth remote that acts as a keyboard arrives here.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is! KeyRepeatEvent) _voice.setTalking(event is KeyDownEvent);
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final cam = _map.camera;
    final k = event.logicalKey;
    // Pan distance shrinks as you zoom in.
    final step = 120.0;
    void pan(double dx, double dy) {
      final c = cam.projectAtZoom(cam.center) + Offset(dx, dy);
      _map.move(cam.unprojectAtZoom(c), cam.zoom);
    }

    if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.equal ||
        k == LogicalKeyboardKey.add ||
        k == LogicalKeyboardKey.numpadAdd) {
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

  List<Rider> _latest = const [];

  void _fitAll() {
    final pts = _latest.map((r) => r.position).toList();
    if (pts.length < 2) {
      _recenter();
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.all(80),
        maxZoom: 17,
      ),
    );
  }

  void _showRiders() {
    const dist = Distance();
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          for (final r in _latest)
            ListTile(
              leading: const Icon(Icons.two_wheeler),
              title: Text(
                r.id == widget.service.myId ? '${r.name} (you)' : r.name,
              ),
              subtitle: Text(
                _me == null || r.id == widget.service.myId
                    ? _ago(r)
                    : '${(dist(_me!, r.position) / 1000).toStringAsFixed(1)} km away · ${_ago(r)}',
              ),
              onTap: () {
                Navigator.pop(context);
                _map.move(r.position, 16);
              },
            ),
        ],
      ),
    );
  }

  String _ago(Rider r) {
    final s = DateTime.now().difference(r.updatedAt).inSeconds;
    return s < 10
        ? 'live'
        : s < 120
        ? '${s}s ago'
        : '${s ~/ 60} min ago';
  }

  Widget _voiceButton() {
    if (widget.service.isDemo) {
      return const Chip(label: Text('Voice needs Firebase (demo mode)'));
    }
    if (!_voice.enabled) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_voice.error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_voice.error!),
              ),
            ),
          FilledButton.icon(
            onPressed: () async {
              await _voice.enable();
              _voice.updatePeers(_latest);
            },
            icon: const Icon(Icons.mic),
            label: const Text('Enable voice'),
          ),
        ],
      );
    }
    final on = _voice.talking;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_voice.error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_voice.error!),
            ),
          ),
        Listener(
          onPointerDown: (_) => _voice.setTalking(true),
          onPointerUp: (_) => _voice.setTalking(false),
          onPointerCancel: (_) => _voice.setTalking(false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            decoration: BoxDecoration(
              color: on ? Colors.redAccent : Colors.deepOrange,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(on ? Icons.mic : Icons.mic_none, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  on
                      ? 'Talking...'
                      : 'Hold to talk (${_voice.connected} linked)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _recenter() {
    final me = _me;
    if (me != null) _map.move(me, _map.camera.zoom);
  }

  @override
  void dispose() {
    _gps?.cancel();
    _beat?.cancel();
    _ridersSub?.cancel();
    _voice.dispose();
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
            icon: const Icon(Icons.groups),
            tooltip: 'Riders',
            onPressed: _showRiders,
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: 'Show everyone',
            onPressed: _fitAll,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy code',
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: widget.code)),
          ),
        ],
      ),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            StreamBuilder<List<Rider>>(
              stream: widget.service.riders(),
              builder: (context, snap) {
                final riders = snap.data ?? const <Rider>[];
                _latest = riders;
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
                    MarkerLayer(
                      markers: [
                        for (final r in riders)
                          Marker(
                            point: r.position,
                            width: 90,
                            height: 60,
                            child: _RiderPin(
                              name: r.name,
                              isMe: r.id == widget.service.myId,
                              stale:
                                  DateTime.now()
                                      .difference(r.updatedAt)
                                      .inSeconds >
                                  90,
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
            ListenableBuilder(
              listenable: _voice,
              builder: (context, _) => Stack(
                children: [
                  // Remote audio plays through these (invisible) elements.
                  for (final r in _voice.renderers.values)
                    Positioned(
                      left: 0,
                      bottom: 0,
                      width: 1,
                      height: 1,
                      child: RTCVideoView(r),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24,
                    child: Center(child: _voiceButton()),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'in',
            onPressed: () => _zoom(1),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'out',
            onPressed: () => _zoom(-1),
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'me',
            onPressed: _recenter,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}

class _RiderPin extends StatelessWidget {
  final String name;
  final bool isMe;
  final bool stale;
  const _RiderPin({required this.name, required this.isMe, this.stale = false});

  @override
  Widget build(BuildContext context) {
    final color = isMe ? Colors.lightBlueAccent : Colors.deepOrange;
    return Opacity(
      opacity: stale ? 0.4 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              name,
              style: const TextStyle(fontSize: 11, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.two_wheeler, color: color, size: 30),
        ],
      ),
    );
  }
}
