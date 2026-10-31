import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'firebase_config.dart';
import 'group_service.dart';
import 'home_page.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GroupService service;
  try {
    if (kIsWeb && !firebaseConfigured) throw StateError('no web config');
    await Firebase.initializeApp(options: kIsWeb ? firebaseWebOptions : null);
    service = FirebaseGroupService();
  } catch (_) {
    // No Firebase config yet (see README): run with simulated riders.
    service = DemoGroupService();
  }
  runApp(AirApp(service: service));
}

class AirApp extends StatelessWidget {
  final GroupService service;
  const AirApp({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raasta',
      debugShowCheckedModeBanner: false,
      theme: buildRaastaTheme(brightness: Brightness.light),
      darkTheme: buildRaastaTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.dark,
      home: HomePage(service: service),
    );
  }
}
