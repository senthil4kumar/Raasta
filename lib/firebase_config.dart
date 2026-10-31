import 'package:firebase_core/firebase_core.dart';

/// Web app config from the Firebase console (Project settings > Your apps).
/// These values identify the project and are not secrets; access is
/// controlled by the Realtime Database rules. Leave empty for demo mode.
const _apiKey = 'AIzaSyAFguJINT2RyVbar7AxjNhTa_NWOR-j4W4';
const _appId = '1:335660282870:web:ac791135e6638f25d00dd7';
const _messagingSenderId = '335660282870';
const _projectId = 'air-rider';
const _databaseUrl =
    'https://air-rider-default-rtdb.asia-southeast1.firebasedatabase.app';
const _authDomain = 'air-rider.firebaseapp.com';

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
