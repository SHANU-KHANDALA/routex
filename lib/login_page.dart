import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  late TabController tabController;
  bool isLoading = false;

  // Controllers
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();

  final TextEditingController _signupNameController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupPasswordController =
      TextEditingController();
  // Removed phone controller

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    // Removed phone controller dispose
    tabController.dispose();
    super.dispose();
  }

  void showToast(String msg) {
    Fluttertoast.showToast(msg: msg);
  }

  Future<void> handleLogin() async {
    if (_loginEmailController.text.isEmpty ||
        _loginPasswordController.text.isEmpty) {
      showToast("Please fill in all fields");
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text.trim(),
      );
      showToast("Welcome back!");
    } on FirebaseAuthException catch (e) {
      showToast(e.message ?? "Login failed");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleSignup() async {
    if (_signupEmailController.text.isEmpty ||
        _signupPasswordController.text.isEmpty) {
      showToast("Please fill in all fields");
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _signupEmailController.text.trim(),
            password: _signupPasswordController.text.trim(),
          );

      if (_signupNameController.text.isNotEmpty) {
        await userCredential.user?.updateDisplayName(
          _signupNameController.text.trim(),
        );
      }

      showToast("Account created successfully!");
    } on FirebaseAuthException catch (e) {
      showToast(e.message ?? "Signup failed");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFFFFFFF), Color(0xFFE8F5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, size: 18),
                        SizedBox(width: 6),
                        Text("Back to Home"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Image.asset("assets/routex-logo.jpg", height: 70),
                  const SizedBox(height: 12),
                  const Text(
                    "RouteX",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text("Track your bus in real-time"),
                  const SizedBox(height: 20),

                  TabBar(
                    controller: tabController,
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: "Login"),
                      Tab(text: "Sign Up"),
                    ],
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 500,
                    child: TabBarView(
                      controller: tabController,
                      children: [loginCard(), signupCard()],
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Text(
                    "By continuing, you agree to our Terms of Service and Privacy Policy",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget loginCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Welcome Back",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text("Sign in to your account"),
            const SizedBox(height: 20),

            TextField(
              controller: _loginEmailController,
              decoration: inputDecoration("Email", Icons.email),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _loginPasswordController,
              obscureText: true,
              decoration: inputDecoration("Password", Icons.lock),
            ),

            const SizedBox(height: 10),

            TextButton(onPressed: () {}, child: const Text("Forgot Password?")),

            const Spacer(),

            ElevatedButton(
              onPressed: isLoading ? null : handleLogin,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(45),
              ),
              child: Text(isLoading ? "Signing in..." : "Sign In"),
            ),
          ],
        ),
      ),
    );
  }

  Widget signupCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Create Account",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text("Sign up to track your bus"),
            const SizedBox(height: 20),

            TextField(
              controller: _signupNameController,
              decoration: inputDecoration("Full Name", Icons.person),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _signupEmailController,
              decoration: inputDecoration("Email", Icons.email),
            ),

            // REMOVED THE PHONE TEXTFIELD HERE
            const SizedBox(height: 16),

            TextField(
              controller: _signupPasswordController,
              obscureText: true,
              decoration: inputDecoration("Password", Icons.lock),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: isLoading ? null : handleSignup,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(45),
              ),
              child: Text(isLoading ? "Creating account..." : "Create Account"),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 20),
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
