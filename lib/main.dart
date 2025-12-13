import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 1. Added Firebase Core
import 'firebase_options.dart'; // 2. Added the generated config file
import 'login_page.dart';
import 'dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RouteX',
      initialRoute: "/",
      routes: {
        "/": (context) => const AuthPage(),
        "/dashboard": (context) => const DashboardPage(),
      },
    );
  }
}
