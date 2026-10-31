import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'firebase_config.dart';
import 'group_service.dart';
import 'home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GroupService service;
  try {
    if (kIsWeb && !firebaseConfigured) throw StateError('no web config');
    await Firebase.initializeApp(
        options: kIsWeb ? firebaseWebOptions : null);
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
      title: 'Air',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: HomePage(service: service),
    );
  }
}
