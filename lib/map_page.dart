import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'group_service.dart';
import 'audio_unlock.dart';
import 'directions_sheet.dart';
import 'rider.dart';
import 'routing.dart';
import 'theme/app_theme.dart';
import 'voice.dart';
import 'widgets/glass_surface.dart';
import 'widgets/pressable_scale.dart';

const _palette = [
  Color(0xFFE8710A),
  Color(0xFF9334E6),
  Color(0xFF188038),
  Color(0xFFD93025),
  Color(0xFF12B5CB),
  Color(0xFFC2185B),
];

Color _colorFor(String id) => _palette[id.hashCode.abs() % _palette.length];

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
  List<Rider> _latest = const [];
  StreamSubscription<GroupRoute?>? _routeSub;
  GroupRoute? _groupRoute;
  RouteInfo? _routeInfo;
  String? _routeError;

  @override
  void initState() {
    super.initState();
    _startLocation();
    _ridersSub = widget.service.riders().listen((r) {
      setState(() => _latest = r);
      _voice.updatePeers(r);
    });
    _routeSub = widget.service.route().listen(_onGroupRoute);
  }

  /// A route only I can see, which takes priority over the group's route.
  GroupRoute? _localRoute;

  /// Who my voice goes to: 'all' or one rider's id for a private talk.
  String _talkTarget = VoiceController.everyone;

  GroupRoute? get _route => _localRoute ?? _groupRoute;

  Future<void> _onGroupRoute(GroupRoute? r) async {
    _groupRoute = r;
    if (_localRoute == null) await _refreshRoute();
  }

  Future<void> _refreshRoute() async {
    final r = _route;
    setState(() {
      _routeInfo = null;
      _routeError = null;
    });
    if (r == null) return;
    try {
      final info = await fetchRoute(r.start.pos, r.dest.pos);
      if (!mounted || _route != r) return;
      setState(() {
        _routeInfo = info;
        _routeError = info == null ? 'No driving route found' : null;
      });
      if (info != null) {
        _map.fitCamera(
          CameraFit.coordinates(
            coordinates: info.points,
            padding: const EdgeInsets.fromLTRB(50, 130, 50, 260),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _routeError = 'Could not load route');
    }
  }

  Future<void> _planRide() async {
    final pick = await showModalBottomSheet<RoutePick>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DirectionsSheet(me: _me),
    );
    if (pick == null) return;
    final r = GroupRoute(pick.start, pick.dest);
    if (pick.shared) {
      _localRoute = null;
      await widget.service.setRoute(pick.start, pick.dest);
      // If the group route is unchanged, the stream stays quiet: refresh now.
      _groupRoute = r;
      await _refreshRoute();
    } else {
      _localRoute = r;
      await _refreshRoute();
    }
  }

  Future<void> _clearRoute() async {
    if (_localRoute != null) {
      _localRoute = null;
      await _refreshRoute();
    } else {
      await widget.service.clearRoute();
    }
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
      if (event is! KeyRepeatEvent) {
        _voice.setTalking(event is KeyDownEvent, target: _effectiveTarget());
      }
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final cam = _map.camera;
    final k = event.logicalKey;
    const step = 120.0;
    void pan(double dx, double dy) {
      final c = cam.projectAtZoom(cam.center) + Offset(dx, dy);
      _map.move(cam.unprojectAtZoom(c), cam.zoom);
    }

    if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.equal ||
        k == LogicalKeyboardKey.add ||
        k == LogicalKeyboardKey.numpadAdd) {
      _zoom(1);
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.minus ||
        k == LogicalKeyboardKey.numpadSubtract) {
      _zoom(-1);
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

  void _fitAll() {
    final pts = _latest.map((r) => r.position).toList();
    if (pts.length < 2) {
      _recenter();
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.fromLTRB(60, 120, 60, 220),
        maxZoom: 17,
      ),
    );
  }

  void _recenter() {
    final me = _me;
    if (me != null) _map.move(me, _map.camera.zoom);
  }

  String _distanceTo(Rider r) {
    final me = _me;
    if (me == null) return '';
    final m = const Distance()(me, r.position);
    return m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';
  }

  bool _isStale(Rider r) =>
      DateTime.now().difference(r.updatedAt).inSeconds > 90;

  /// The chosen target, or everyone if that rider is no longer on voice.
  String _effectiveTarget() {
    if (_talkTarget == VoiceController.everyone) return _talkTarget;
    final ok = _latest.any((r) => r.id == _talkTarget && r.voiceOn);
    return ok ? _talkTarget : VoiceController.everyone;
  }

  bool _heardByMe(Rider r) =>
      r.talking &&
      (r.talkTo == null ||
          r.talkTo == VoiceController.everyone ||
          r.talkTo == widget.service.myId);

  Future<void> _leave() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this ride?'),
        content: const Text(
          'You will stop sharing your location and voice with the group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, leave'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) Navigator.of(context).pop();
  }

  String _nameOf(String id) {
    for (final r in _latest) {
      if (r.id == id) return r.name;
    }
    return 'a rider';
  }

  void _showVoiceDetails() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: _voice,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_voice.status.isEmpty && _voice.log.isEmpty)
                const Text('Nothing yet. Tap Enable voice first.'),
              for (final e in _voice.status.entries)
                Text('${_nameOf(e.key)}: ${e.value}'),
              const Divider(),
              for (final l in _voice.log)
                Text(l, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gps?.cancel();
    _beat?.cancel();
    _ridersSub?.cancel();
    _routeSub?.cancel();
    _voice.dispose();
    _focus.dispose();
    widget.service.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Listener(
            onPointerDown: (_) => resumeAllAudio(),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: const LatLng(20.5937, 78.9629),
                    initialZoom: 4,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onTap: (_, _) => _focus.requestFocus(),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      maxNativeZoom: 19,
                      userAgentPackageName: 'com.air.air_rider',
                    ),
                    if (_routeInfo != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routeInfo!.points,
                            strokeWidth: 6,
                            color: const Color(0xFF1A73E8),
                            borderStrokeWidth: 2,
                            borderColor: Colors.white,
                          ),
                        ],
                      ),
                    if (_route != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _route!.start.pos,
                            width: 24,
                            height: 24,
                            child: const Icon(
                              Icons.trip_origin,
                              color: Color(0xFF188038),
                            ),
                          ),
                          Marker(
                            point: _route!.dest.pos,
                            width: 40,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.place,
                              size: 40,
                              color: Color(0xFFD93025),
                            ),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (final r in _latest)
                          Marker(
                            point: r.position,
                            width: 44,
                            height: 44,
                            child: _RiderPin(
                              name: r.name,
                              color: _colorFor(r.id),
                              isMe: r.id == widget.service.myId,
                              stale: _isStale(r),
                            ),
                          ),
                      ],
                    ),
                    const RichAttributionWidget(
                      alignment: AttributionAlignment.bottomLeft,
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                // Top bar
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: GlassSurface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Leave ride',
                            onPressed: _leave,
                          ),
                          Expanded(
                            child: GestureDetector(
                              // Hidden: long-press the title for connection details.
                              onLongPress: _showVoiceDetails,
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Ride ',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      Text(
                                        widget.code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      InkResponse(
                                        radius: 20,
                                        onTap: () {
                                          Clipboard.setData(
                                            ClipboardData(text: widget.code),
                                          );
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text('Code copied'),
                                                ),
                                              );
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.copy_rounded,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${_latest.length} rider${_latest.length == 1 ? '' : 's'} on the map',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.directions),
                            tooltip: 'Plan a route',
                            onPressed: _planRide,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Positioned(
                    top: 96,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      child: GlassSurface(
                        padding: const EdgeInsets.all(14),
                        borderRadius: BorderRadius.circular(16),
                        tint: scheme.secondaryContainer.withValues(alpha: 0.85),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: scheme.secondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!)),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Map buttons
                Positioned(
                  right: 12,
                  bottom: 210,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RoundButton(icon: Icons.add, onTap: () => _zoom(1)),
                      const SizedBox(height: 8),
                      _RoundButton(icon: Icons.remove, onTap: () => _zoom(-1)),
                      const SizedBox(height: 8),
                      _RoundButton(icon: Icons.fit_screen, onTap: _fitAll),
                      const SizedBox(height: 8),
                      _RoundButton(
                        icon: Icons.my_location,
                        onTap: _recenter,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
                // Bottom: rider chips and voice
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_route != null) _routeCard(),
                        SizedBox(
                          height: 56,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              for (final r in _latest)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _RiderChip(
                                    rider: r,
                                    color: _colorFor(r.id),
                                    isMe: r.id == widget.service.myId,
                                    distance: r.id == widget.service.myId
                                        ? 'you'
                                        : _distanceTo(r),
                                    stale: _isStale(r),
                                    voiceOn: r.voiceOn,
                                    talking: _heardByMe(r),
                                    onTap: () => _map.move(r.position, 16),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListenableBuilder(
                          listenable: _voice,
                          builder: (context, _) => Stack(
                            alignment: Alignment.center,
                            children: [
                              // Remote audio plays through these invisible elements.
                              for (final r in _voice.renderers.values)
                                SizedBox(
                                  width: 1,
                                  height: 1,
                                  child: RTCVideoView(r),
                                ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _voiceRoster(),
                                  const SizedBox(height: 8),
                                  _voiceControl(),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _routeCard() {
    final r = _route!;
    final info = _routeInfo;
    final private = _localRoute != null;
    final scheme = Theme.of(context).colorScheme;
    final card = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GlassSurface(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            Icon(Icons.place_rounded, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.dest.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${private ? 'Only you · ' : 'Shared with group · '}${_routeError ?? (info == null ? 'Finding route...' : '${info.distanceText} · ${info.durationText} by car')}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
              tooltip: private ? 'Clear my route' : 'Clear route for everyone',
              onPressed: _clearRoute,
            ),
          ],
        ),
      ),
    );
    return AnimatedSwitcher(
      duration: motionDuration(context, const Duration(milliseconds: 320)),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(r.dest.name), child: card),
    );
  }

  /// Who is on voice and who is talking, by name, right on the main screen.
  Widget _voiceRoster() {
    if (widget.service.isDemo && _latest.isEmpty) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;
    final others = _latest.where((r) => r.id != widget.service.myId).toList();
    if (others.isEmpty) return const SizedBox();
    final me = widget.service.myId;
    final talkers = others
        .where(
          (r) =>
              r.talking &&
              (r.talkTo == null || r.talkTo == VoiceController.everyone),
        )
        .map((r) => r.name)
        .toList();
    final privateTalkers = others
        .where((r) => r.talking && r.talkTo == me)
        .map((r) => r.name)
        .toList();
    final onVoice = others.where((r) => r.voiceOn).map((r) => r.name).toList();
    final offVoice = others
        .where((r) => !r.voiceOn)
        .map((r) => r.name)
        .toList();
    final talkingNow = talkers.isNotEmpty || privateTalkers.isNotEmpty;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: GlassSurface(
        key: ValueKey('$talkers|$privateTalkers|$onVoice|$offVoice'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        borderRadius: BorderRadius.circular(18),
        blur: 14,
        tint: talkingNow ? scheme.primary.withValues(alpha: 0.85) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (talkingNow)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (privateTalkers.isNotEmpty)
                    _rosterLine(
                      Icons.lock,
                      '${privateTalkers.join(', ')} ${privateTalkers.length == 1 ? 'is' : 'are'} talking to you privately',
                    ),
                  if (talkers.isNotEmpty)
                    _rosterLine(
                      Icons.graphic_eq,
                      '${talkers.join(', ')} ${talkers.length == 1 ? 'is' : 'are'} talking',
                    ),
                ],
              )
            else ...[
              Text(
                onVoice.isEmpty
                    ? 'Nobody else is on voice yet'
                    : 'On voice: ${onVoice.join(', ')}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (offVoice.isNotEmpty && onVoice.isNotEmpty)
                Text(
                  'Not on voice: ${offVoice.join(', ')}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rosterLine(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: Colors.white),
        ),
      ),
    ],
  );

  /// Choose who hears you: everyone, or one rider who is on voice.
  Widget _targetPicker() {
    final others = _latest
        .where((r) => r.id != widget.service.myId && r.voiceOn)
        .toList();
    if (others.isEmpty) return const SizedBox();
    final target = _effectiveTarget();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: const Icon(Icons.groups_rounded, size: 18),
              label: const Text('Everyone'),
              selected: target == VoiceController.everyone,
              onSelected: (_) =>
                  setState(() => _talkTarget = VoiceController.everyone),
            ),
          ),
          for (final r in others)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: const Icon(Icons.lock_outline, size: 16),
                label: Text(r.name),
                selected: target == r.id,
                onSelected: (_) => setState(() => _talkTarget = r.id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _voiceControl() {
    final scheme = Theme.of(context).colorScheme;
    if (widget.service.isDemo) {
      return const Chip(label: Text('Voice needs Firebase (demo mode)'));
    }
    if (!_voice.enabled) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_voice.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
              child: Text(
                _voice.error!,
                style: TextStyle(color: scheme.error, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(200, 56),
              shape: const StadiumBorder(),
            ),
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
    final target = _effectiveTarget();
    final private = target != VoiceController.everyone;
    final accent = private ? const Color(0xFF7B3FE4) : scheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _targetPicker(),
        const SizedBox(height: 8),
        Listener(
          onPointerDown: (_) => _voice.setTalking(true, target: target),
          onPointerUp: (_) => _voice.setTalking(false),
          onPointerCancel: (_) => _voice.setTalking(false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: on ? 92 : 80,
            height: on ? 92 : 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? const Color(0xFFD93025) : accent,
              boxShadow: [
                BoxShadow(
                  color: (on ? const Color(0xFFD93025) : accent).withValues(
                    alpha: 0.4,
                  ),
                  blurRadius: on ? 24 : 10,
                  spreadRadius: on ? 6 : 0,
                ),
              ],
            ),
            child: Icon(
              on ? Icons.mic : (private ? Icons.lock : Icons.mic_none),
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 6),
        GlassSurface(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          borderRadius: BorderRadius.circular(14),
          blur: 12,
          child: Text(
            on
                ? 'Talking...'
                : private
                ? 'Hold to talk privately to ${_nameOf(target)}'
                : 'Hold to talk to everyone',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        if (_voice.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _voice.error!,
              style: TextStyle(color: scheme.error, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _RoundButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: GlassSurface(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(22),
        blur: 14,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: color ?? scheme.onSurface),
        ),
      ),
    );
  }
}

class _RiderChip extends StatelessWidget {
  final Rider rider;
  final Color color;
  final bool isMe;
  final String distance;
  final bool stale;
  final bool voiceOn;
  final bool talking;
  final VoidCallback onTap;
  const _RiderChip({
    required this.rider,
    required this.color,
    required this.isMe,
    required this.distance,
    required this.stale,
    required this.voiceOn,
    required this.talking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: GlassSurface(
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        borderRadius: BorderRadius.circular(28),
        blur: 12,
        child: Opacity(
          opacity: stale ? 0.5 : 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color,
                    child: Text(
                      rider.name.isEmpty ? '?' : rider.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: _MicBadge(on: voiceOn, talking: talking),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '${rider.name} (you)' : rider.name,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontSize: 13),
                  ),
                  Text(
                    stale
                        ? '$distance · last seen'
                        : '$distance · ${talking
                              ? 'talking'
                              : voiceOn
                              ? 'voice on'
                              : 'voice off'}',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiderPin extends StatelessWidget {
  final String name;
  final Color color;
  final bool isMe;
  final bool stale;
  const _RiderPin({
    required this.name,
    required this.color,
    required this.isMe,
    required this.stale,
  });

  @override
  Widget build(BuildContext context) {
    final fill = isMe ? const Color(0xFF1A73E8) : color;
    return Opacity(
      opacity: stale ? 0.5 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 6),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Positioned(
            top: -20,
            left: -40,
            right: -40,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 3),
                  ],
                ),
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MicBadge extends StatelessWidget {
  final bool on;
  final bool talking;
  const _MicBadge({required this.on, required this.talking});

  @override
  Widget build(BuildContext context) {
    final color = talking
        ? const Color(0xFFD93025)
        : on
        ? const Color(0xFF188038)
        : Colors.grey.shade600;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: talking ? 20 : 18,
      height: talking ? 20 : 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: talking
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
            : null,
      ),
      child: Icon(
        on ? Icons.mic : Icons.mic_off,
        size: 11,
        color: Colors.white,
      ),
    );
  }
}
