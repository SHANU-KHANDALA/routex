import 'package:flutter/material.dart';
import 'login_page.dart';
import 'dashboard_page.dart';

void main() {
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
        "/": (context) => const AuthPage(), // FIXED
        "/dashboard": (context) => const DashboardPage(),
      },
    );
  }
}
