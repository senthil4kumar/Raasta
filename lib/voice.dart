import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'group_service.dart';
import 'rider.dart';
import 'voice_config.dart';

/// Push-to-talk over a full mesh of WebRTC audio links (fine for a handful of
/// riders). Everyone keeps their mic track muted until [setTalking] is called.
class VoiceController extends ChangeNotifier {
  final GroupService service;
  VoiceController(this.service);

  Map<String, dynamic> get _ice => {'iceServers': iceServers};

  /// Per-rider link state, shown on screen to help debug connections.
  final status = <String, String>{};

  /// Recent connection events, shown on screen while we debug voice.
  final log = <String>[];

  void _log(String m) {
    log.add(m);
    if (log.length > 8) log.removeAt(0);
    notifyListeners();
  }

  static String _s(String id) => id.length > 4 ? id.substring(0, 4) : id;

  MediaStream? _local;
  StreamSubscription<Signal>? _sig;
  final _pcs = <String, RTCPeerConnection>{};
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
      _mute(true);
      enabled = true;
      error = null;
      _log('mic on, me=${_s(service.myId)}');
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
  }

  void setTalking(bool on) {
    if (!enabled || talking == on) return;
    talking = on;
    _mute(!on);
    notifyListeners();
  }

  /// Call whenever the rider list changes. The rider with the smaller id
  /// starts each call so the two sides never both send offers.
  void updatePeers(List<Rider> riders) {
    if (!enabled) return;
    final ids = riders
        .map((r) => r.id)
        .where((id) => id != service.myId)
        .toSet();
    for (final id in ids) {
      if (!_pcs.containsKey(id) && service.myId.compareTo(id) < 0) _call(id);
    }
    for (final id in _pcs.keys.toList()) {
      if (!ids.contains(id)) _close(id);
    }
  }

  Future<RTCPeerConnection> _create(String id) async {
    final pc = await createPeerConnection(_ice);
    for (final t in _local!.getAudioTracks()) {
      await pc.addTrack(t, _local!);
    }
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
      notifyListeners();
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
    notifyListeners();
  }

  Future<void> _call(String id) async {
    try {
      final pc = await _create(id);
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await service.sendSignal(id, {'type': 'offer', 'sdp': offer.sdp});
      _log('sent offer to ${_s(id)}');
    } catch (e) {
      _fail('Voice error: $e');
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
    final r = renderers.remove(id);
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
