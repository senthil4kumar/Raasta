import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class Place {
  final String name;
  final LatLng pos;
  const Place(this.name, this.pos);
}

class RouteInfo {
  final List<LatLng> points;
  final double meters;
  final double seconds;
  const RouteInfo(this.points, this.meters, this.seconds);

  String get distanceText => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

  String get durationText {
    final m = (seconds / 60).round();
    if (m < 60) return '$m min';
    return '${m ~/ 60} h ${m % 60} min';
  }
}

/// Free place search by Photon (OpenStreetMap data), biased towards [near].
Future<List<Place>> searchPlaces(String query, {LatLng? near}) async {
  final q = query.trim();
  if (q.length < 3) return const [];
  final uri = Uri.https('photon.komoot.io', '/api/', {
    'q': q,
    'limit': '6',
    if (near != null) 'lat': '${near.latitude}',
    if (near != null) 'lon': '${near.longitude}',
  });
  final res = await http.get(uri).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) return const [];
  final features = (jsonDecode(res.body)['features'] as List?) ?? const [];
  return [
    for (final f in features)
      if (f['geometry']?['coordinates'] is List)
        Place(
          _label(f['properties'] as Map? ?? const {}),
          LatLng(
            (f['geometry']['coordinates'][1] as num).toDouble(),
            (f['geometry']['coordinates'][0] as num).toDouble(),
          ),
        ),
  ];
}

String _label(Map p) {
  final parts = <String>[];
  for (final k in ['name', 'street', 'district', 'city', 'state']) {
    final v = p[k];
    if (v is String && v.isNotEmpty && !parts.contains(v)) parts.add(v);
  }
  return parts.take(3).join(', ');
}

/// Driving route from the free OSRM demo server (fine for prototype use).
Future<RouteInfo?> fetchRoute(LatLng a, LatLng b) async {
  final uri = Uri.https(
    'router.project-osrm.org',
    '/route/v1/driving/${a.longitude},${a.latitude};${b.longitude},${b.latitude}',
    {'overview': 'full', 'geometries': 'geojson'},
  );
  final res = await http.get(uri).timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) return null;
  final routes = (jsonDecode(res.body)['routes'] as List?) ?? const [];
  if (routes.isEmpty) return null;
  final r = routes.first as Map;
  final coords = (r['geometry']['coordinates'] as List);
  return RouteInfo(
    [
      for (final c in coords)
        LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ],
    (r['distance'] as num).toDouble(),
    (r['duration'] as num).toDouble(),
  );
}
