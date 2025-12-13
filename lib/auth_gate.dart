import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // 1. Listen to the stream of authentication changes
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 2. If the snapshot has data, the user is logged in -> Show Dashboard
        if (snapshot.hasData) {
          return const DashboardPage();
        }

        // 3. Otherwise, the user is NOT logged in -> Show Login Page (AuthPage)
        return const AuthPage();
      },
    );
  }
}
