import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soreconnect/screens/auth/register_screen.dart';
import 'package:soreconnect/screens/consumer/consumer_dashboard.dart';
import 'package:soreconnect/screens/meter_reader/meter_reader_dashboard.dart';
import 'package:soreconnect/screens/teller/teller_dashboard.dart';
import 'package:soreconnect/screens/director/director_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Enter email');
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Enter password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Sign in
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Get user role from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        setState(() => _errorMessage = 'User not found');
        _isLoading = false;
        return;
      }

      String role = userDoc.get('user_type') ?? 'consumer';

      if (!mounted) return;

      // Navigate based on role
      if (role == 'consumer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ConsumerDashboard()),
        );
      } else if (role == 'meter_reader') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MeterReaderDashboard()),
        );
      } else if (role == 'teller') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TellerDashboard()),
        );
      } else if (role == 'director') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DirectorDashboard()),
        );
      } else {
        setState(() => _errorMessage = 'Invalid role: $role');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _errorMessage = 'No user found';
      } else if (e.code == 'wrong-password') {
        _errorMessage = 'Wrong password';
      } else {
        _errorMessage = e.message;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
Widget build(BuildContext context) {

  return Scaffold(

    body: Container(

      width: double.infinity,

      decoration: const BoxDecoration(

        gradient: LinearGradient(

          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,

          colors: [

            Color(0xFFD50000), // RED
            Color(0xFFFFC107), // YELLOW
          ],
        ),
      ),

      child: Center(

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(24),

          child: Container(

            padding: const EdgeInsets.all(25),

            decoration: BoxDecoration(

              color: Colors.white.withOpacity(0.95),

              borderRadius: BorderRadius.circular(25),

              boxShadow: const [

                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                // LOGO
                ClipRRect(

                  borderRadius: BorderRadius.circular(20),

                  child: Image.asset(
                    'assets/soreco_logo.png',
                    height: 140,
                    width: 140,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 20),

                // TITLE
                const Text(

                  "SORECONNECT",

                  style: TextStyle(

                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD50000),
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(

                  "Sorsogon Electric Cooperative 1",

                  textAlign: TextAlign.center,

                  style: TextStyle(

                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 35),

                // EMAIL
                TextField(

                  controller: _emailController,

                  decoration: InputDecoration(

                    labelText: "Email",

                    prefixIcon: const Icon(
                      Icons.email,
                      color: Color(0xFFD50000),
                    ),

                    filled: true,
                    fillColor: Colors.grey.shade100,

                    border: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(15),
                    ),

                    enabledBorder: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(15),

                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 36, 34, 32),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // PASSWORD
                TextField(

                  controller: _passwordController,

                  obscureText: _obscurePassword,

                  decoration: InputDecoration(

                    labelText: "Password",

                    prefixIcon: const Icon(
                      Icons.lock,
                      color: Color(0xFFD50000),
                    ),

                    suffixIcon: IconButton(

                      icon: Icon(

                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,

                        color: Colors.orange,
                      ),

                      onPressed: () {

                        setState(() {

                          _obscurePassword =
                              !_obscurePassword;
                        });
                      },
                    ),

                    filled: true,
                    fillColor: Colors.grey.shade100,

                    border: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(15),
                    ),

                    enabledBorder: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(15),

                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 20, 19, 19),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ERROR
                if (_errorMessage != null)

                  Padding(

                    padding: const EdgeInsets.only(
                      bottom: 15,
                    ),

                    child: Text(

                      _errorMessage!,

                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // LOGIN BUTTON
                SizedBox(

                  width: double.infinity,
                  height: 55,

                  child: ElevatedButton(

                    onPressed:
                        _isLoading ? null : _login,

                    style: ElevatedButton.styleFrom(

                      backgroundColor:
                          const Color(0xFFD50000),

                      foregroundColor: Colors.white,

                      shape: RoundedRectangleBorder(

                        borderRadius:
                            BorderRadius.circular(15),
                      ),
                    ),

                    child: _isLoading

                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )

                        : const Text(

                            "LOGIN",

                            style: TextStyle(

                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 15),

                // REGISTER
                TextButton(

                  onPressed: () {

                    Navigator.push(

                      context,

                      MaterialPageRoute(

                        builder: (_) =>
                            const RegisterScreen(),
                      ),
                    );
                  },

                  child: const Text(

                    "Create Consumer Account",

                    style: TextStyle(

                      color: Color(0xFFD50000),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
