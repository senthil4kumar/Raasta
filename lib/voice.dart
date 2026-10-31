import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'group_service.dart';
import 'audio_unlock.dart';
import 'rider.dart';
import 'voice_config.dart';

/// Push-to-talk over a full mesh of WebRTC audio links (fine for a handful of
/// riders). Everyone keeps their mic track muted until [setTalking] is called.
class VoiceController extends ChangeNotifier {
  final GroupService service;
  VoiceController(this.service);

  List<Map<String, dynamic>> _iceServers = const [];

  Map<String, dynamic> get _ice => {'iceServers': _iceServers};

  /// Per-rider link state, shown on screen to help debug connections.
  final status = <String, String>{};

  /// Recent connection events, shown on screen while we debug voice.
  final log = <String>[];

  void _log(String m) {
    log.add(m);
    if (log.length > 8) log.removeAt(0);
    notifyListeners();
  }

  /// Rider names by id, so logs and status show names instead of codes.
  final _names = <String, String>{};

  String _s(String id) => _names[id] ?? 'a rider';

  MediaStream? _local;
  StreamSubscription<Signal>? _sig;
  final _pcs = <String, RTCPeerConnection>{};
  final _starting = <String>{};

  /// One microphone track per rider link, so a private call can send audio to
  /// one rider only while the others stay silent.
  final _tracks = <String, MediaStreamTrack>{};
  String _target = _everyone;

  /// Pass as the talk target to speak to the whole group.
  static const _everyone = 'all';
  static const everyone = _everyone;
  final _pendingIce = <String, List<RTCIceCandidate>>{};
  final renderers = <String, RTCVideoRenderer>{};

  bool enabled = false;
  bool talking = false;
  String? error;

  int get connected => renderers.length;

  Future<void> enable() async {
    try {
      _local = await navigator.mediaDevices.getUserMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true},
        'video': false,
      });
      _iceServers = await loadIceServers();
      _mute(true);
      enabled = true;
      error = null;
      _log('mic on, relay=${_iceServers.length > 1 ? 'yes' : 'no'}');
      service.setVoiceState(enabled: true, talking: false);
      _sig = service.signals().listen(
        _onSignal,
        onError: (e) => _fail('Voice error: $e'),
      );
    } catch (e) {
      _fail('Microphone is blocked or unavailable: $e');
    }
    notifyListeners();
  }

  void _fail(String m) {
    _log(m);
    error = m;
    notifyListeners();
  }

  void _mute(bool mute) {
    for (final t in _local?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !mute;
    }
    for (final t in _tracks.values) {
      t.enabled = false;
    }
  }

  bool _sendsTo(String id) => _target == _everyone || _target == id;

  /// Start or stop talking. [target] is [everyone] or one rider's id for a
  /// private conversation: only that rider's link carries your voice.
  void setTalking(bool on, {String target = _everyone}) {
    resumeAllAudio();
    if (!enabled) return;
    if (talking == on && (!on || _target == target)) return;
    talking = on;
    _target = on ? target : _everyone;
    _tracks.forEach((id, t) => t.enabled = on && _sendsTo(id));
    service.setVoiceState(
      enabled: true,
      talking: on,
      talkTo: on ? target : null,
    );
    notifyListeners();
  }

  /// Call whenever the rider list changes. The rider with the smaller id
  /// starts each call so the two sides never both send offers.
  void updatePeers(List<Rider> riders) {
    for (final r in riders) {
      _names[r.id] = r.name;
    }
    if (!enabled) return;
    final ids = riders
        .map((r) => r.id)
        .where((id) => id != service.myId)
        .toSet();
    for (final id in ids) {
      if (!_pcs.containsKey(id) &&
          !_starting.contains(id) &&
          service.myId.compareTo(id) < 0) {
        _call(id);
      }
    }
    for (final id in _pcs.keys.toList()) {
      if (!ids.contains(id)) _close(id);
    }
  }

  Future<RTCPeerConnection> _create(String id) async {
    final pc = await createPeerConnection(_ice);
    final mine = await _local!.getAudioTracks().first.clone();
    mine.enabled = talking && _sendsTo(id);
    _tracks[id] = mine;
    await pc.addTrack(mine, _local!);
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      service.sendSignal(id, {
        'type': 'ice',
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };
    pc.onTrack = (e) {
      _log('audio from ${_s(id)}: ${e.streams.length} stream');
      if (e.streams.isNotEmpty) _attach(id, e.streams.first);
    };
    pc.onIceConnectionState = (s) {
      status[id] = s.name.replaceFirst('RTCIceConnectionState', '');
      _log('${_s(id)}: ${status[id]}');
    };
    pc.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _close(id);
      }
    };
    _pcs[id] = pc;
    return pc;
  }

  Future<void> _attach(String id, MediaStream stream) async {
    final r = renderers[id] ?? RTCVideoRenderer();
    if (!renderers.containsKey(id)) await r.initialize();
    r.srcObject = stream;
    renderers[id] = r;
    resumeAllAudio();
    notifyListeners();
  }

  Future<void> _call(String id) async {
    _starting.add(id);
    try {
      final pc = await _create(id);
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await service.sendSignal(id, {'type': 'offer', 'sdp': offer.sdp});
      _log('sent offer to ${_s(id)}');
    } catch (e) {
      _fail('Voice error: $e');
    } finally {
      _starting.remove(id);
    }
  }

  Future<void> _onSignal(Signal s) async {
    try {
      final type = s.data['type'];
      if (type != 'ice') _log('got $type from ${_s(s.from)}');
      if (type == 'offer') {
        await _close(s.from);
        final pc = await _create(s.from);
        await pc.setRemoteDescription(
          RTCSessionDescription(s.data['sdp'] as String, 'offer'),
        );
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await service.sendSignal(s.from, {'type': 'answer', 'sdp': answer.sdp});
        _log('sent answer to ${_s(s.from)}');
        await _flushIce(s.from);
      } else if (type == 'answer') {
        final pc = _pcs[s.from];
        if (pc == null) return;
        await pc.setRemoteDescription(
          RTCSessionDescription(s.data['sdp'] as String, 'answer'),
        );
        await _flushIce(s.from);
      } else if (type == 'ice') {
        final c = RTCIceCandidate(
          s.data['candidate'] as String?,
          s.data['sdpMid'] as String?,
          (s.data['sdpMLineIndex'] as num?)?.toInt(),
        );
        final pc = _pcs[s.from];
        if (pc != null && await pc.getRemoteDescription() != null) {
          await pc.addCandidate(c);
        } else {
          (_pendingIce[s.from] ??= []).add(c);
        }
      }
    } catch (e) {
      _fail('Voice error: $e');
    }
  }

  Future<void> _flushIce(String id) async {
    final pc = _pcs[id];
    final queued = _pendingIce.remove(id) ?? const [];
    for (final c in queued) {
      await pc?.addCandidate(c);
    }
  }

  Future<void> _close(String id) async {
    _pendingIce.remove(id);
    status.remove(id);
    final pc = _pcs.remove(id);
    final track = _tracks.remove(id);
    final r = renderers.remove(id);
    track?.stop();
    await pc?.close();
    if (r != null) {
      r.srcObject = null;
      await r.dispose();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sig?.cancel();
    for (final id in _pcs.keys.toList()) {
      _close(id);
    }
    for (final t in _local?.getTracks() ?? <MediaStreamTrack>[]) {
      t.stop();
    }
    _local?.dispose();
    super.dispose();
  }
}
