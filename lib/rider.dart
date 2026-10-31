import 'package:latlong2/latlong.dart';

class Rider {
  final String id;
  final String name;
  final LatLng position;
  final DateTime updatedAt;

  /// Voice chat state shared through the group, so everyone can see who is
  /// on voice and who is talking.
  final bool voiceOn;
  final bool talking;

  /// Who the rider is talking to: 'all' or one rider's id (private talk).
  final String? talkTo;

  const Rider({
    required this.id,
    required this.name,
    required this.position,
    required this.updatedAt,
    this.voiceOn = false,
    this.talking = false,
    this.talkTo,
  });
}
