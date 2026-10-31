import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';

import 'rider.dart';

/// Group membership and live locations. Two backends: Firebase for real
/// phones, and an offline demo that simulates riders so the app can be tried
/// before any cloud setup.
abstract class GroupService {
  String get myId;
  bool get isDemo;

  /// Creates a group and returns its 6-digit join code.
  Future<String> createGroup(String name);

  /// Returns false when no group exists with this code.
  Future<bool> joinGroup(String code, String name);

  Future<void> updateLocation(LatLng position);
  Stream<List<Rider>> riders();
  Future<void> leave();

  /// Voice call set-up messages addressed to me (WebRTC offers, answers, ICE).
  Stream<Signal> signals();
  Future<void> sendSignal(String to, Map<String, dynamic> data);
}

class Signal {
  final String from;
  final Map<String, dynamic> data;
  const Signal(this.from, this.data);
}

String _newCode() {
  final r = Random.secure();
  return List.generate(6, (_) => r.nextInt(10)).join();
}

class FirebaseGroupService implements GroupService {
  final _db = FirebaseDatabase.instance;
  String? _code;
  String _name = 'Rider';

  @override
  bool get isDemo => false;

  @override
  String get myId => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _signIn() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  DatabaseReference _member() => _db.ref('groups/$_code/riders/$myId');

  Future<void> _enter(String code, String name) async {
    _code = code;
    _name = name;
    final ref = _member();
    await ref.set({'name': name, 'ts': ServerValue.timestamp});
    // Rider disappears from everyone's map if the app dies or loses signal.
    await ref.onDisconnect().remove();
  }

  @override
  Future<String> createGroup(String name) async {
    await _signIn();
    var code = _newCode();
    while ((await _db.ref('groups/$code/created').get()).exists) {
      code = _newCode();
    }
    await _db.ref('groups/$code/created').set(ServerValue.timestamp);
    await _enter(code, name);
    return code;
  }

  @override
  Future<bool> joinGroup(String code, String name) async {
    await _signIn();
    code = code.trim().toUpperCase();
    final snap = await _db.ref('groups/$code/created').get();
    if (!snap.exists) return false;
    await _enter(code, name);
    return true;
  }

  @override
  Future<void> updateLocation(LatLng p) => _member().update({
    'lat': p.latitude,
    'lng': p.longitude,
    'name': _name,
    'ts': ServerValue.timestamp,
  });

  @override
  Stream<List<Rider>> riders() {
    return _db.ref('groups/$_code/riders').onValue.map((event) {
      final out = <Rider>[];
      final value = event.snapshot.value;
      if (value is Map) {
        value.forEach((id, v) {
          if (v is Map && v['lat'] != null && v['lng'] != null) {
            out.add(
              Rider(
                id: id as String,
                name: (v['name'] ?? 'Rider') as String,
                position: LatLng(
                  (v['lat'] as num).toDouble(),
                  (v['lng'] as num).toDouble(),
                ),
                updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  (v['ts'] as num?)?.toInt() ?? 0,
                ),
              ),
            );
          }
        });
      }
      return out;
    });
  }

  @override
  Future<void> leave() async {
    await _member().onDisconnect().cancel();
    await _member().remove();
    await _db.ref('groups/$_code/rtc/$myId').remove();
  }

  @override
  Stream<Signal> signals() async* {
    final inbox = _db.ref('groups/$_code/rtc/$myId');
    await for (final e in inbox.onChildAdded) {
      final v = e.snapshot.value;
      e.snapshot.ref.remove();
      // Ignore leftovers from an earlier session, but keep calls that were
      // sent while this rider had not enabled voice yet.
      final ts = (v is Map ? v['ts'] : null) as num?;
      if (ts == null ||
          DateTime.now().millisecondsSinceEpoch - ts.toInt() > 120000) {
        continue;
      }
      if (v is Map && v['from'] is String && v['data'] is Map) {
        yield Signal(
          v['from'] as String,
          Map<String, dynamic>.from(v['data'] as Map),
        );
      }
    }
  }

  @override
  Future<void> sendSignal(String to, Map<String, dynamic> data) =>
      _db.ref('groups/$_code/rtc/$to').push().set({
        'from': myId,
        'data': data,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
}

/// Offline stand-in: two fake riders orbit around wherever you are.
class DemoGroupService implements GroupService {
  final _controller = StreamController<List<Rider>>.broadcast();
  LatLng? _me;
  String _name = 'Me';
  Timer? _timer;
  double _t = 0;

  @override
  bool get isDemo => true;

  @override
  String get myId => 'me';

  @override
  Future<String> createGroup(String name) async {
    _start(name);
    return '123456';
  }

  @override
  Future<bool> joinGroup(String code, String name) async {
    _start(name);
    return true;
  }

  void _start(String name) {
    _name = name;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _t += 0.05;
      _emit();
    });
  }

  void _emit() {
    final me = _me;
    if (me == null) return;
    final now = DateTime.now();
    LatLng orbit(double radius, double phase) => LatLng(
      me.latitude + radius * sin(_t + phase),
      me.longitude + radius * cos(_t + phase),
    );
    _controller.add([
      Rider(id: 'me', name: _name, position: me, updatedAt: now),
      Rider(id: 'a', name: 'Arjun', position: orbit(0.004, 0), updatedAt: now),
      Rider(
        id: 'b',
        name: 'Meera',
        position: orbit(0.007, 2.5),
        updatedAt: now,
      ),
    ]);
  }

  @override
  Future<void> updateLocation(LatLng position) async {
    _me = position;
    _emit();
  }

  @override
  Stream<List<Rider>> riders() => _controller.stream;

  @override
  Future<void> leave() async => _timer?.cancel();

  @override
  Stream<Signal> signals() => const Stream.empty();

  @override
  Future<void> sendSignal(String to, Map<String, dynamic> data) async {}
}
