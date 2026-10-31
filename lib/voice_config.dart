import 'dart:convert';

import 'package:http/http.dart' as http;

/// Optional TURN relay for riders whose networks block direct audio links
/// (for example phones on mobile data). Paste the credentials URL from the
/// TURN provider's dashboard (Metered "Credential API"); leave empty to use
/// only Google's free STUN server.
const turnCredentialsUrl = '';

const _stun = {'urls': 'stun:stun.l.google.com:19302'};

Future<List<Map<String, dynamic>>> loadIceServers() async {
  final servers = <Map<String, dynamic>>[_stun];
  if (turnCredentialsUrl.isEmpty) return servers;
  try {
    final res = await http
        .get(Uri.parse(turnCredentialsUrl))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      for (final s in jsonDecode(res.body) as List) {
        servers.add(Map<String, dynamic>.from(s as Map));
      }
    }
  } catch (_) {
    // Fall back to STUN only.
  }
  return servers;
}
