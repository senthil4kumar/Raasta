import 'package:firebase_core/firebase_core.dart';

/// Web app config from the Firebase console (Project settings > Your apps).
/// These values identify the project and are not secrets; access is
/// controlled by the Realtime Database rules. Leave empty for demo mode.
const _apiKey = '';
const _appId = '';
const _messagingSenderId = '';
const _projectId = '';
const _databaseUrl = '';
const _authDomain = '';

bool get firebaseConfigured =>
    _apiKey.isNotEmpty && _appId.isNotEmpty && _databaseUrl.isNotEmpty;

const firebaseWebOptions = FirebaseOptions(
  apiKey: _apiKey,
  appId: _appId,
  messagingSenderId: _messagingSenderId,
  projectId: _projectId,
  databaseURL: _databaseUrl,
  authDomain: _authDomain,
);
