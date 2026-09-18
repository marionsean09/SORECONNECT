import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:soreconnect/screens/auth/login_screen.dart';
import 'package:soreconnect/screens/consumer/consumer_dashboard.dart';

// ============================================================
// VERIFY EMAIL SCREEN
//
// Two modes:
// - Sign-up verification (pendingEmail null): shown right after
//   consumer registration, and on login if the account's email
//   still isn't verified. Blocks entry until verified.
// - Email change confirmation (pendingEmail set): pushed from
//   Edit Profile after editing the email. Non-blocking — the
//   consumer can dismiss and keep using their current email
//   until they confirm the new one.
//
// Both use FirebaseAuth's own verification link — no OTP/backend
// needed.
// ============================================================

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.pendingEmail});

  final String? pendingEmail;

  @override
  State<VerifyEmailScreen> createState() =>
      _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _autoCheckTimer;
  Timer? _resendCooldownTimer;

  bool _isChecking = false;
  bool _isResending = false;
  bool _isButtonPressed = false;
  int _resendCooldown = 0;

  String? _message;
  Color _messageColor = Colors.black54;

  bool get _isEmailChange => widget.pendingEmail != null;

  // Strong ease-out — starts fast so the entrance feels responsive
  // rather than a generic linear/ease-in-out fade.
  static const Curve _easeOut = Cubic(0.23, 1, 0.32, 1);

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Silently re-check every few seconds so the user is moved
    // along automatically once they tap the link in their email.
    _autoCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkVerified(silent: true),
    );

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
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: _easeOut,
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    _resendCooldownTimer?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _checkVerified({bool silent = false}) async {
    final user = _auth.currentUser;

    if (user == null) return;

    if (!silent) {
      setState(() {
        _isChecking = true;
        _message = null;
      });
    }

    try {
      await user.reload();

      final refreshedUser = _auth.currentUser;

      if (refreshedUser == null) return;

      final confirmed = _isEmailChange
          ? (refreshedUser.email?.toLowerCase() ==
              widget.pendingEmail!.toLowerCase())
          : refreshedUser.emailVerified;

      if (confirmed) {
        _autoCheckTimer?.cancel();

        if (!mounted) return;

        if (_isEmailChange) {
          // Keep Firestore's cached email in sync with the now
          // up-to-date Auth email before requiring a fresh login,
          // and clear the pending-change marker so the dashboard
          // stops reminding them to confirm it.
          await FirebaseFirestore.instance
              .collection('users')
              .doc(refreshedUser.uid)
              .set(
            {
              'email': widget.pendingEmail,
              'pendingEmail': FieldValue.delete(),
            },
            SetOptions(merge: true),
          );

          await _auth.signOut();

          if (!mounted) return;

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const LoginScreen(
                infoMessage:
                    'Email updated. Please log in again with '
                    'your new email.',
              ),
            ),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const ConsumerDashboard(),
            ),
            (route) => false,
          );
        }

        return;
      }

      if (!silent && mounted) {
        setState(() {
          _message = _isEmailChange
              ? 'Not confirmed yet. Open the email and tap the '
                  'confirmation link, then try again.'
              : 'Not verified yet. Open the email and tap the '
                  'verification link, then try again.';
          _messageColor = Colors.orange;
        });
      }
    } catch (e) {
      // Logged even when silent (the periodic background check) so
      // a flaky/offline check on a real device leaves a trace instead
      // of failing invisibly.
      debugPrint('Verification check failed: $e');

      if (!silent && mounted) {
        setState(() {
          _message = 'Failed to check status: $e';
          _messageColor = Colors.red;
        });
      }
    } finally {
      if (!silent && mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _resendEmail() async {
    final user = _auth.currentUser;

    if (user == null || _resendCooldown > 0) return;

    setState(() {
      _isResending = true;
      _message = null;
    });

    try {
      if (_isEmailChange) {
        await user.verifyBeforeUpdateEmail(widget.pendingEmail!);
      } else {
        await user.sendEmailVerification();
      }

      if (!mounted) return;

      setState(() {
        _message = _isEmailChange
            ? 'Confirmation email sent. Please check your inbox '
                '(and spam folder).'
            : 'Verification email sent. Please check your inbox '
                '(and spam folder).';
        _messageColor = Colors.green;
        _resendCooldown = 60;
      });

      _resendCooldownTimer?.cancel();
      _resendCooldownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }

          setState(() {
            _resendCooldown--;
          });

          if (_resendCooldown <= 0) {
            timer.cancel();
          }
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _message = e.code == 'too-many-requests'
            ? 'Too many requests. Please wait a bit before '
                'trying again.'
            : (e.message ?? 'Failed to send email.');
        _messageColor = Colors.red;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    _autoCheckTimer?.cancel();

    await _auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayEmail =
        widget.pendingEmail ?? (_auth.currentUser?.email ?? '');

    return Scaffold(
      appBar: _isEmailChange
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.white,
              title: const Text('Confirm Email'),
            )
          : null,
      extendBodyBehindAppBar: true,
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 420),
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
                      color: const Color(0xFFD50000)
                          .withValues(alpha: 0.08),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFD50000)
                            .withValues(alpha: 0.08),
                      ),
                      child: Icon(
                        _isEmailChange
                            ? Icons.mark_email_read_outlined
                            : Icons.mark_email_unread_outlined,
                        size: 46,
                        color: const Color(0xFFD50000),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isEmailChange
                          ? 'Confirm Your New Email'
                          : 'Verify Your Email',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD50000),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isEmailChange
                          ? 'We sent a confirmation link to:'
                          : 'We sent a verification link to:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayEmail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isEmailChange
                          ? 'Open the email and tap the link to '
                              'switch your sign-in email, then come '
                              'back to this app — it will continue '
                              'automatically once confirmed. Your '
                              'current email still works until then.'
                          : 'Open the email and tap the link to '
                              'verify your account, then come back '
                              'to this app — it will continue '
                              'automatically once verified.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedSize(
                      duration: const Duration(
                        milliseconds: 220,
                      ),
                      curve: _easeOut,
                      alignment: Alignment.topCenter,
                      child: _message == null
                          ? const SizedBox(
                              width: double.infinity,
                            )
                          : Padding(
                        padding: const EdgeInsets.only(
                          bottom: 14,
                        ),
                        child: Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _messageColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Listener(
                      onPointerDown: (_) {
                        if (!_isChecking) {
                          setState(
                            () => _isButtonPressed = true,
                          );
                        }
                      },
                      onPointerUp: (_) => setState(
                        () => _isButtonPressed = false,
                      ),
                      onPointerCancel: (_) => setState(
                        () => _isButtonPressed = false,
                      ),
                      child: AnimatedScale(
                        scale: _isButtonPressed ? 0.97 : 1.0,
                        duration: const Duration(
                          milliseconds: 120,
                        ),
                        curve: Curves.easeOut,
                        child: SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _isChecking
                            ? null
                            : () => _checkVerified(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFD50000),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isChecking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(
                          _isChecking
                              ? 'Checking...'
                              : (_isEmailChange
                                  ? "I've Confirmed"
                                  : "I've Verified My Email"),
                        ),
                      ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed:
                            (_isResending || _resendCooldown > 0)
                                ? null
                                : _resendEmail,
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              const Color(0xFFD50000),
                          side: BorderSide(
                            color: const Color(0xFFD50000)
                                .withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isResending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFD50000),
                                ),
                              )
                            : const Icon(
                                Icons.email_outlined,
                              ),
                        label: Text(
                          _resendCooldown > 0
                              ? 'Resend in ${_resendCooldown}s'
                              : (_isEmailChange
                                  ? 'Resend Confirmation Email'
                                  : 'Resend Verification Email'),
                        ),
                      ),
                    ),
                    if (!_isEmailChange) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Colors.grey.shade600,
                          overlayColor:
                              Colors.grey.withValues(
                            alpha: 0.08,
                          ),
                        ),
                        onPressed: _logout,
                        child: const Text(
                          'Log out',
                          style: TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
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
