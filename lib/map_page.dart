import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import 'group_service.dart';
import 'audio_unlock.dart';
import 'directions_sheet.dart';
import 'rider.dart';
import 'routing.dart';
import 'theme/app_theme.dart';
import 'voice.dart';
import 'widgets/glass_surface.dart';
import 'widgets/luxe_controls.dart' show TalkPulse;
import 'widgets/pressable_scale.dart';

// Muted, metallic rider tones: distinct but quiet next to the amber accent.
const _palette = [
  Color(0xFFE6E2DA),
  Color(0xFF9FB0C2),
  Color(0xFFB7A48A),
  Color(0xFF8FB8A9),
  Color(0xFFC49A9A),
  Color(0xFFA79BC4),
];

const _ink = Color(0xFF14100A);

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
      final before = {for (final x in _latest) x.id: x};
      final firstBatch = !_gotRiders;
      _gotRiders = true;
      setState(() => _latest = r);
      _voice.updatePeers(r);
      if (firstBatch) return;
      final me = widget.service.myId;
      for (final x in r) {
        if (x.id == me) continue;
        final old = before[x.id];
        if (old == null) {
          _toast('${x.name} joined the ride');
        } else if (!old.voiceOn && x.voiceOn) {
          _toast('${x.name} is on voice');
        }
      }
      for (final old in before.values) {
        if (old.id != me && !r.any((x) => x.id == old.id)) {
          _toast('${old.name} left the ride');
        }
      }
    });
    _routeSub = widget.service.route().listen(_onGroupRoute);
  }

  /// A route only I can see, which takes priority over the group's route.
  GroupRoute? _localRoute;

  bool _gotRiders = false;
  bool _setupDismissed = false;
  bool _invited = false;
  bool _allSetToastShown = false;

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

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 150),
        ),
      );
  }

  Future<void> _invite() async {
    String link;
    try {
      link = Uri.base.origin + Uri.base.path;
    } catch (_) {
      link = 'the Raasta web app';
    }
    final text =
        'Join my ride on Raasta! Open $link and enter the code ${widget.code}.';
    setState(() => _invited = true);
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      _toast('Invite copied. Paste it into WhatsApp or a message.');
    }
  }

  void _showRiderSheet(Rider r) {
    final isMe = r.id == widget.service.myId;
    final canPrivate = !isMe && r.voiceOn && _voice.enabled;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Initial(
                  name: r.name,
                  color: _colorFor(r.id),
                  size: 48,
                  fontSize: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? '${r.name} (you)' : r.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        [
                          if (!isMe) _distanceTo(r),
                          r.voiceOn ? 'On voice' : 'Not on voice',
                        ].where((e) => e.isNotEmpty).join(' · '),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () {
                Navigator.pop(sheetContext);
                _map.move(r.position, 16);
              },
              icon: const Icon(Icons.my_location),
              label: const Text('Show on map'),
            ),
            if (!isMe) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: canPrivate
                    ? () {
                        Navigator.pop(sheetContext);
                        setState(() => _talkTarget = r.id);
                        _toast(
                          'Hold the talk button to speak privately to ${r.name}',
                        );
                      }
                    : null,
                icon: const Icon(Icons.lock),
                label: Text('Talk privately to ${r.name}'),
              ),
              if (!canPrivate)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    !_voice.enabled
                        ? 'Turn on voice first (the mic button at the bottom).'
                        : '${r.name} has not turned on voice yet. Ask them to tap Enable voice.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

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
                            color: RaastaColors.amber,
                            borderStrokeWidth: 2.5,
                            borderColor: const Color(0xFF0B0B0D),
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
                              color: Color(0xFF0B0B0D),
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
                              color: RaastaColors.amber,
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
                      borderRadius: BorderRadius.circular(10),
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
                                      Text(
                                        'Ride ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w300,
                                              letterSpacing: 1.6,
                                            ),
                                      ),
                                      Text(
                                        widget.code,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: RaastaColors.amber,
                                              fontWeight: FontWeight.w400,
                                              fontSize: 20,
                                              letterSpacing: 4,
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
                                        .bodySmall
                                        ?.copyWith(
                                          color: RaastaColors.muted,
                                          letterSpacing: 0.8,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.person_add_alt_1),
                            tooltip: 'Invite friends',
                            onPressed: _invite,
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
                Positioned(
                  top: 84,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    child: ListenableBuilder(
                      listenable: _voice,
                      builder: (context, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_error != null && _me == null) _errorBanner(),
                          _setupCard(),
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
                                    onTap: () => _showRiderSheet(r),
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
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            const Icon(Icons.place_rounded, color: RaastaColors.amber),
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
        borderRadius: BorderRadius.circular(8),
        blur: 14,
        tint: talkingNow ? scheme.primary.withValues(alpha: 0.92) : null,
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

  Widget _errorBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassSurface(
        padding: const EdgeInsets.all(14),
        borderRadius: BorderRadius.circular(8),
        tint: scheme.secondaryContainer.withValues(alpha: 0.92),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: scheme.secondary),
            const SizedBox(width: 10),
            Expanded(child: Text(_error!)),
          ],
        ),
      ),
    );
  }

  /// First-run checklist: clear, upfront feedback on what is ready and what
  /// still needs a tap.
  Widget _setupCard() {
    final locationOk = _me != null;
    final voiceOk = _voice.enabled || widget.service.isDemo;
    final inviteOk = _invited || _latest.length > 1;
    final done = locationOk && voiceOk && inviteOk;
    if (done && !_allSetToastShown) {
      _allSetToastShown = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _toast('You are all set. Happy riding!'),
      );
    }
    if (_setupDismissed || done) return const SizedBox();
    final scheme = Theme.of(context).colorScheme;
    Widget row(bool ok, String text, {String? action, VoidCallback? onTap}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.radio_button_unchecked,
              color: ok ? RaastaColors.amber : scheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
            if (!ok && action != null)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  foregroundColor: RaastaColors.amber,
                  side: BorderSide(
                    color: RaastaColors.amber.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                onPressed: onTap,
                child: Text(action),
              ),
          ],
        ),
      );
    }

    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Get ready to ride',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Hide',
                onPressed: () => setState(() => _setupDismissed = true),
              ),
            ],
          ),
          row(
            locationOk,
            locationOk
                ? 'Your location is live'
                : (_error ?? 'Finding your location...'),
          ),
          row(
            voiceOk,
            voiceOk ? 'Voice is on' : 'Turn on voice to talk with the group',
            action: 'Turn on',
            onTap: () async {
              await _voice.enable();
              _voice.updatePeers(_latest);
            },
          ),
          row(
            inviteOk,
            inviteOk
                ? 'Friends invited'
                : 'Invite friends with code ${widget.code}',
            action: 'Invite',
            onTap: _invite,
          ),
        ],
      ),
    );
  }

  Widget _rosterLine(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: _ink, size: 18),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: _ink),
        ),
      ),
    ],
  );

  /// Choose who hears you: everyone, or one rider who is on voice.
  Widget _targetPicker() {
    final others = _latest.where((r) => r.id != widget.service.myId).toList();
    if (others.isEmpty) return const SizedBox();
    final target = _effectiveTarget();
    return SizedBox(
      height: 48,
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
                avatar: Icon(
                  r.voiceOn ? Icons.lock_outline : Icons.mic_off,
                  size: 16,
                ),
                label: Text(r.voiceOn ? r.name : '${r.name} (voice off)'),
                selected: target == r.id,
                onSelected: r.voiceOn
                    ? (_) => setState(() => _talkTarget = r.id)
                    : (_) => _toast(
                        '${r.name} has not turned on voice yet. Ask them to tap Enable voice.',
                      ),
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
            style: FilledButton.styleFrom(minimumSize: const Size(220, 54)),
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
    final accent = private ? scheme.onSurface : scheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _targetPicker(),
        const SizedBox(height: 8),
        Listener(
          onPointerDown: (_) => _voice.setTalking(true, target: target),
          onPointerUp: (_) => _voice.setTalking(false),
          onPointerCancel: (_) => _voice.setTalking(false),
          child: TalkPulse(
            active: on,
            color: RaastaColors.amber,
            size: 92,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              width: on ? 100 : 92,
              height: on ? 100 : 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on
                    ? RaastaColors.amber
                    : const Color(0xFF0B0B0D).withValues(alpha: 0.82),
                border: Border.all(
                  color: on ? RaastaColors.amberLight : accent,
                  width: on ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: RaastaColors.amber.withValues(alpha: on ? 0.45 : 0.14),
                    blurRadius: on ? 30 : 16,
                    spreadRadius: on ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                on ? Icons.mic : (private ? Icons.lock_outline : Icons.mic_none),
                color: on ? _ink : accent,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        GlassSurface(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          borderRadius: BorderRadius.circular(6),
          blur: 12,
          child: Text(
            on
                ? 'Talking...'
                : private
                ? 'Hold to talk privately to ${_nameOf(target)}'
                : 'Hold to talk to everyone',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: on ? RaastaColors.amberLight : null,
            ),
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
        borderRadius: BorderRadius.circular(23),
        blur: 14,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, size: 21, color: color ?? scheme.onSurface),
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
                  _Initial(name: rider.name, color: color, size: 40),
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
                        ?.copyWith(fontSize: 13, letterSpacing: 0.6),
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

/// Dark disc with a thin coloured ring and the rider's initial.
class _Initial extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  final double fontSize;
  const _Initial({
    required this.name,
    required this.color,
    required this.size,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF16161A),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
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
    final ring = isMe ? RaastaColors.amber : color;
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
              color: const Color(0xFF0B0B0D),
              border: Border.all(color: ring, width: 2),
              boxShadow: [
                BoxShadow(
                  color: isMe
                      ? RaastaColors.amber.withValues(alpha: 0.55)
                      : Colors.black54,
                  blurRadius: isMe ? 12 : 6,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                color: ring,
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
            ),
          ),
          Positioned(
            top: -22,
            left: -40,
            right: -40,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xE60B0B0D),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0x40FFFFFF), width: 0.6),
                ),
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFEDEBE8),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.8,
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
        ? RaastaColors.amber
        : on
        ? const Color(0xFFE6E2DA)
        : const Color(0xFF3A3A3F);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: talking ? 20 : 18,
      height: talking ? 20 : 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: const Color(0xFF0B0B0D), width: 1.5),
        boxShadow: talking
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
            : null,
      ),
      child: Icon(
        on ? Icons.mic : Icons.mic_off,
        size: 11,
        color: on ? _ink : const Color(0xFF9A9AA0),
      ),
    );
  }
}
