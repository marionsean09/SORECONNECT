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
  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _errorMessage;

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    final email =
        _emailController.text.trim();

    final password =
        _passwordController.text;

    // ==========================================================
    // VALIDATE EMAIL
    // ==========================================================

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your email address.';
      });
      return;
    }

    // ==========================================================
    // VALIDATE PASSWORD
    // ==========================================================

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ========================================================
      // SIGN IN USING FIREBASE AUTHENTICATION
      //
      // IMPORTANT:
      // The email here must match the email stored in
      // Firebase Authentication.
      // ========================================================

      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user =
          userCredential.user;

      if (user == null) {
        throw Exception(
          'Unable to retrieve user information.',
        );
      }

      // ========================================================
      // GET USER DATA FROM FIRESTORE
      // ========================================================

      final DocumentSnapshot userDoc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      // ========================================================
      // CHECK IF USER DOCUMENT EXISTS
      // ========================================================

      if (!userDoc.exists) {
        await _auth.signOut();

        if (!mounted) return;

        setState(() {
          _errorMessage =
              'User profile was not found.';
        });

        return;
      }

      // ========================================================
      // GET USER ROLE
      // ========================================================

      final userData =
          userDoc.data()
              as Map<String, dynamic>;

      final String role =
          (userData['user_type'] ??
                  'consumer')
              .toString()
              .toLowerCase()
              .trim();

      if (!mounted) return;

      // ========================================================
      // NAVIGATE BASED ON ROLE
      // ========================================================

      switch (role) {
        case 'consumer':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const ConsumerDashboard(),
            ),
          );
          break;

        case 'meter_reader':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const MeterReaderDashboard(),
            ),
          );
          break;

        case 'teller':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const TellerDashboard(),
            ),
          );
          break;

        case 'director':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const DirectorDashboard(),
            ),
          );
          break;

        default:
          await _auth.signOut();

          setState(() {
            _errorMessage =
                'Invalid user role: $role';
          });
      }
    }

    // ==========================================================
    // FIREBASE AUTHENTICATION ERRORS
    // ==========================================================

    on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message =
              'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message =
              'No account found with this email.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message =
              'Incorrect email or password.';
          break;

        case 'user-disabled':
          message =
              'This account has been disabled.';
          break;

        case 'too-many-requests':
          message =
              'Too many login attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message =
              'Network error. Please check your internet connection.';
          break;

        default:
          message =
              e.message ??
                  'Login failed. Please try again.';
      }

      setState(() {
        _errorMessage = message;
      });
    }

    // ==========================================================
    // OTHER ERRORS
    // ==========================================================

    catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'An error occurred: $e';
      });
    }

    // ==========================================================
    // STOP LOADING
    // ==========================================================

    finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // DISPOSE CONTROLLERS
  // ============================================================

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
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
              Color(0xFFD50000),
              Color(0xFFFFC107),
            ],
          ),
        ),

        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),

            child: Container(
              padding:
                  const EdgeInsets.all(25),

              decoration: BoxDecoration(
                color:
                    Colors.white.withValues(alpha: 0.95),

                borderRadius:
                    BorderRadius.circular(25),

                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),

              child: Column(
                mainAxisSize:
                    MainAxisSize.min,

                children: [

                  // ==================================================
                  // LOGO
                  // ==================================================

                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(20),

                    child: Image.asset(
                      'assets/soreco_logo.png',

                      height: 140,
                      width: 140,

                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // ==================================================
                  // TITLE
                  // ==================================================

                  const Text(
                    'SORECONNECT',

                    style: TextStyle(
                      fontSize: 32,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(0xFFD50000),
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  const Text(
                    'Sorsogon Electric Cooperative 1',

                    textAlign:
                        TextAlign.center,

                    style: TextStyle(
                      fontSize: 16,
                      color:
                          Colors.black54,
                    ),
                  ),

                  const SizedBox(
                    height: 35,
                  ),

                  // ==================================================
                  // EMAIL
                  // ==================================================

                  TextField(
                    controller:
                        _emailController,

                    keyboardType:
                        TextInputType.emailAddress,

                    textInputAction:
                        TextInputAction.next,

                    decoration:
                        InputDecoration(
                      labelText: 'Email',

                      prefixIcon:
                          const Icon(
                        Icons.email,
                        color:
                            Color(0xFFD50000),
                      ),

                      filled: true,

                      fillColor:
                          Colors.grey.shade100,

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                      ),

                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),

                        borderSide:
                            const BorderSide(
                          color: Color.fromARGB(
                            255,
                            36,
                            34,
                            32,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // ==================================================
                  // PASSWORD
                  // ==================================================

                  TextField(
                    controller:
                        _passwordController,

                    obscureText:
                        _obscurePassword,

                    onSubmitted: (_) {
                      if (!_isLoading) {
                        _login();
                      }
                    },

                    decoration:
                        InputDecoration(
                      labelText: 'Password',

                      prefixIcon:
                          const Icon(
                        Icons.lock,
                        color:
                            Color(0xFFD50000),
                      ),

                      suffixIcon:
                          IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,

                          color:
                              Colors.orange,
                        ),

                        onPressed: () {
                          setState(() {
                            _obscurePassword =
                                !_obscurePassword;
                          });
                        },
                      ),

                      filled: true,

                      fillColor:
                          Colors.grey.shade100,

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                      ),

                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),

                        borderSide:
                            const BorderSide(
                          color: Color.fromARGB(
                            255,
                            20,
                            19,
                            19,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // ==================================================
                  // ERROR MESSAGE
                  // ==================================================

                  if (_errorMessage != null)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 15,
                      ),

                      child: Text(
                        _errorMessage!,

                        textAlign:
                            TextAlign.center,

                        style:
                            const TextStyle(
                          color: Colors.red,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                  // ==================================================
                  // LOGIN BUTTON
                  // ==================================================

                  SizedBox(
                    width:
                        double.infinity,

                    height: 55,

                    child: ElevatedButton(
                      onPressed:
                          _isLoading
                              ? null
                              : _login,

                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(
                          0xFFD50000,
                        ),

                        foregroundColor:
                            Colors.white,

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            15,
                          ),
                        ),
                      ),

                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color:
                                  Colors.white,
                            )
                          : const Text(
                              'LOGIN',

                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  // ==================================================
                  // REGISTER
                  // ==================================================

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
                      'Create Consumer Account',

                      style: TextStyle(
                        color:
                            Color(0xFFD50000),

                        fontWeight:
                            FontWeight.bold,
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