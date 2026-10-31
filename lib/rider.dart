import 'package:latlong2/latlong.dart';

class Rider {
  final String id;
  final String name;
  final LatLng position;
  final DateTime updatedAt;

  const Rider({
    required this.id,
    required this.name,
    required this.position,
    required this.updatedAt,
  });
}
