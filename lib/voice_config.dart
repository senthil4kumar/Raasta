/// Optional TURN relay for riders whose networks block direct audio links.
/// Leave empty to use only Google's free STUN server.
const turnUrls = <String>[];
const turnUsername = '';
const turnCredential = '';

List<Map<String, dynamic>> get iceServers => [
  {'urls': 'stun:stun.l.google.com:19302'},
  if (turnUrls.isNotEmpty)
    {'urls': turnUrls, 'username': turnUsername, 'credential': turnCredential},
];
