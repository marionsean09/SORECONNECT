import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:soreconnect/screens/auth/register_screen.dart';
import 'package:soreconnect/screens/auth/verify_email_screen.dart';
import 'package:soreconnect/screens/consumer/consumer_dashboard.dart';
import 'package:soreconnect/screens/meter_reader/meter_reader_dashboard.dart';
import 'package:soreconnect/screens/teller/teller_dashboard.dart';
import 'package:soreconnect/screens/director/director_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.infoMessage});

  // Optional heads-up shown above the form — e.g. after an email
  // change forces a fresh login.
  final String? infoMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isButtonPressed = false;

  String? _errorMessage;

  // Strong ease-out — starts fast so the entrance feels responsive
  // rather than a generic linear/ease-in-out fade.
  static const Curve _easeOut = Cubic(0.23, 1, 0.32, 1);

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: _easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceController, curve: _easeOut));

    _entranceController.forward();
  }

  // ============================================================
  // SYNC A CONFIRMED EMAIL CHANGE
  // ============================================================

  Future<void> _syncConfirmedPendingEmail(
    User user,
    Map<String, dynamic> userData,
  ) async {
    final pendingEmail = userData['pendingEmail']?.toString();

    if (pendingEmail == null || pendingEmail.trim().isEmpty) {
      return;
    }

    final pendingLower = pendingEmail.trim().toLowerCase();
    final authEmail = (user.email ?? '').trim().toLowerCase();

    if (authEmail != pendingLower) {
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': pendingEmail,
        'pendingEmail': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // If Firestore is temporarily unavailable, the app can still
      // continue; the background guard will reconcile it on the next
      // dashboard load or a later login attempt.
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    final email = _emailController.text.trim();

    final password = _passwordController.text;

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

      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;

      if (user == null) {
        throw Exception('Unable to retrieve user information.');
      }

      // ========================================================
      // GET USER DATA FROM FIRESTORE
      // ========================================================

      final DocumentSnapshot userDoc = await _firestore
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
          _errorMessage = 'User profile was not found.';
        });

        return;
      }

      // ========================================================
      // GET USER ROLE
      // ========================================================

      final userData = userDoc.data() as Map<String, dynamic>;

      await _syncConfirmedPendingEmail(user, userData);

      final String role = (userData['user_type'] ?? 'consumer')
          .toString()
          .toLowerCase()
          .trim();

      if (!mounted) return;

      // ========================================================
      // NAVIGATE BASED ON ROLE
      // ========================================================

      switch (role) {
        case 'consumer':
          // Refresh the cached emailVerified flag before deciding
          // where to route — it's only accurate as of last sign-in.
          await user.reload();

          final refreshedUser = _auth.currentUser;

          if (!mounted) return;

          if (refreshedUser != null && !refreshedUser.emailVerified) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
            );
            break;
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ConsumerDashboard()),
          );
          break;

        case 'meter_reader':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MeterReaderDashboard()),
          );
          break;

        case 'teller':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TellerDashboard()),
          );
          break;

        case 'director':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DirectorDashboard()),
          );
          break;

        default:
          await _auth.signOut();

          setState(() {
            _errorMessage = 'Invalid user role: $role';
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
          message = 'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message = 'No account found with this email.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;

        case 'user-disabled':
          message = 'This account has been disabled.';
          break;

        case 'too-many-requests':
          message = 'Too many login attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;

        default:
          message = e.message ?? 'Login failed. Please try again.';
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
        _errorMessage = 'An error occurred: $e';
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
    _entranceController.dispose();

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

            colors: [Color(0xFFD50000), Color(0xFFFFC107)],
          ),
        ),

        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),

                child: FadeTransition(
                  opacity: _fadeAnimation,

                  child: SlideTransition(
                    position: _slideAnimation,

                    child: Container(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),

                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),

                        borderRadius: BorderRadius.circular(28),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: const Color(
                              0xFFD50000,
                            ).withValues(alpha: 0.08),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),

                      child: Column(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          // ==================================================
                          // LOGO
                          // ==================================================

                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFD50000,
                                  ).withValues(alpha: 0.18),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),

                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),

                              child: Image.asset(
                                'assets/soreco_logo.png',

                                height: 140,
                                width: 140,

                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ==================================================
                          // TITLE
                          // ==================================================
                          const Text(
                            'SORECONNECT',

                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD50000),
                              letterSpacing: 1.5,
                              height: 1.1,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Sorsogon Electric Cooperative 1',

                            textAlign: TextAlign.center,

                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.2,
                            ),
                          ),

                          if (widget.infoMessage != null) ...[
                            const SizedBox(height: 20),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Color(0xFFD50000),
                                  ),

                                  const SizedBox(width: 8),

                                  Expanded(
                                    child: Text(
                                      widget.infoMessage!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),

                          // ==================================================
                          // EMAIL
                          // ==================================================
                          TextField(
                            controller: _emailController,

                            keyboardType: TextInputType.emailAddress,

                            textInputAction: TextInputAction.next,

                            cursorColor: const Color(0xFFD50000),

                            decoration: InputDecoration(
                              labelText: 'Email',

                              floatingLabelStyle: const TextStyle(
                                color: Color(0xFFD50000),
                              ),

                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Color(0xFFD50000),
                              ),

                              filled: true,

                              fillColor: Colors.grey.shade100,

                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),

                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),

                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),

                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD50000),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ==================================================
                          // PASSWORD
                          // ==================================================
                          TextField(
                            controller: _passwordController,

                            obscureText: _obscurePassword,

                            cursorColor: const Color(0xFFD50000),

                            onSubmitted: (_) {
                              if (!_isLoading) {
                                _login();
                              }
                            },

                            decoration: InputDecoration(
                              labelText: 'Password',

                              floatingLabelStyle: const TextStyle(
                                color: Color(0xFFD50000),
                              ),

                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFFD50000),
                              ),

                              suffixIcon: IconButton(
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 150),
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    key: ValueKey(_obscurePassword),
                                    color: const Color(0xFFD50000),
                                  ),
                                ),

                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),

                              filled: true,

                              fillColor: Colors.grey.shade100,

                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),

                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),

                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),

                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD50000),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ==================================================
                          // ERROR MESSAGE
                          // ==================================================
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: _easeOut,
                            alignment: Alignment.topCenter,
                            child: _errorMessage == null
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(bottom: 15),

                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,

                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),

                                        const SizedBox(width: 8),

                                        Flexible(
                                          child: Text(
                                            _errorMessage!,

                                            textAlign: TextAlign.center,

                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),

                          // ==================================================
                          // LOGIN BUTTON
                          // ==================================================
                          Listener(
                            onPointerDown: (_) {
                              if (!_isLoading) {
                                setState(() => _isButtonPressed = true);
                              }
                            },
                            onPointerUp: (_) =>
                                setState(() => _isButtonPressed = false),
                            onPointerCancel: (_) =>
                                setState(() => _isButtonPressed = false),

                            child: AnimatedScale(
                              scale: _isButtonPressed ? 0.97 : 1.0,
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOut,

                              child: SizedBox(
                                width: double.infinity,

                                height: 55,

                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,

                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD50000),

                                    foregroundColor: Colors.white,

                                    elevation: 0,

                                    shadowColor: Colors.transparent,

                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),

                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text(
                                          'LOGIN',

                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ==================================================
                          // REGISTER
                          // ==================================================
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFD50000),
                              overlayColor: const Color(
                                0xFFD50000,
                              ).withValues(alpha: 0.08),
                            ),

                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },

                            child: const Text(
                              'Create Consumer Account',

                              style: TextStyle(
                                color: Color(0xFFD50000),

                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
