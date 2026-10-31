/// ICE servers for voice. STUN finds the direct route between phones; the
/// TURN relay (Metered free plan) carries audio when a direct link is blocked,
/// for example on mobile data. The relay login is injected at build time
/// (flutter build --dart-define=TURN_USERNAME=... --dart-define=TURN_CREDENTIAL=...)
/// from GitHub secrets, so it is not stored in the source. Without it the app
/// uses STUN only.
const _turnUsername = String.fromEnvironment('TURN_USERNAME');
const _turnCredential = String.fromEnvironment('TURN_CREDENTIAL');

Future<List<Map<String, dynamic>>> loadIceServers() async => [
  {'urls': 'stun:stun.relay.metered.ca:80'},
  {'urls': 'stun:stun.l.google.com:19302'},
  if (_turnUsername.isNotEmpty && _turnCredential.isNotEmpty)
    for (final url in const [
      'turn:global.relay.metered.ca:80',
      'turn:global.relay.metered.ca:80?transport=tcp',
      'turn:global.relay.metered.ca:443',
      'turns:global.relay.metered.ca:443?transport=tcp',
    ])
      {'urls': url, 'username': _turnUsername, 'credential': _turnCredential},
];
