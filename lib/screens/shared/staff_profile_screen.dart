import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:soreconnect/data/sorsogon_address_data.dart';
import 'package:soreconnect/screens/auth/login_screen.dart';
import 'package:soreconnect/screens/auth/verify_email_screen.dart';

// ============================================================
// STAFF PROFILE SCREEN
//
// Shared by the teller, meter reader, and director dashboards —
// each just passes its own role label, Firestore `user_type` value,
// and accent color. Lets staff edit their name, branch, and email
// (with the same re-auth + confirm-by-link flow as the consumer
// profile), and change their password.
// ============================================================

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({
    super.key,
    required this.role,
    required this.userTypeValue,
  });

  // Display label, e.g. "Teller", "Meter Reader", "Director".
  final String role;

  // Firestore `user_type` value, e.g. "teller", "meter_reader",
  // "director".
  final String userTypeValue;

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen>
    with AutomaticKeepAliveClientMixin {
  // Keeps this tab's state (edit mode, unsaved field edits) alive
  // when swiping to another bottom-nav tab, instead of disposing
  // and rebuilding from scratch each time.
  @override
  bool get wantKeepAlive => true;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Matches the app-wide theme color (main.dart's primaryColor) that
  // every other AppBar in the app already resolves to via
  // `Theme.of(context).primaryColor` — kept as a literal here (like
  // the consumer profile screen does) so this screen's accents match
  // even where it doesn't have a BuildContext yet.
  static const orange = Color(0xFFFFA000);
  static const background = Color(0xFFF5F7F5);

  // ============================================================
  // PROFILE CONTROLLERS
  // ============================================================

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();

  String? _selectedMunicipality;

  // ============================================================
  // PROFILE STATE
  // ============================================================

  bool _editingProfile = false;
  bool _savingProfile = false;
  bool _profileLoaded = false;
  bool _saveButtonPressed = false;
  bool _logoutButtonPressed = false;

  String? _pendingEmail;
  bool _resendingPendingEmail = false;

  // ============================================================
  // PASSWORD CONTROLLERS
  // ============================================================

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _changingPassword = false;

  Color get _accent => orange;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  void _showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorDialog(String title, Object error) {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(title),
          content: SingleChildScrollView(
            child: SelectableText(
              error.toString(),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  List<String> get _municipalities {
    return getSorsogonSecondDistrictMunicipalities();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await _auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      final data = doc.data() ?? {};

      _fullNameController.text = data['full_name']?.toString() ?? '';

      // Firebase Auth's email is the source of truth for the
      // actual sign-in email — Firestore's copy is only a cache
      // and can briefly lag behind right after an email change.
      _emailController.text = user.email?.trim().isNotEmpty == true
          ? user.email!
          : (data['email']?.toString() ?? '');

      final pendingEmail = data['pendingEmail']?.toString();

      _pendingEmail =
          (pendingEmail != null &&
              pendingEmail.isNotEmpty &&
              pendingEmail.toLowerCase() != (user.email ?? '').toLowerCase())
          ? pendingEmail
          : null;

      String? municipality = data['municipality']?.toString();

      if (municipality != null && !_municipalities.contains(municipality)) {
        municipality = null;
      }

      if (mounted) {
        setState(() {
          _selectedMunicipality = municipality;
          _profileLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading staff profile: $e');

      if (!mounted) return;

      setState(() {
        _profileLoaded = true;
      });

      _showErrorDialog('Unable to load your profile', e);
    }
  }

  // ============================================================
  // EMAIL ERROR MESSAGE
  // ============================================================

  String _emailErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email is already used by another account.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'requires-recent-login':
        return 'Please confirm your password to continue.';
      default:
        return e.message ?? 'Unable to update email.';
    }
  }

  // ============================================================
  // RESEND PENDING EMAIL CONFIRMATION
  // ============================================================

  Future<void> _resendPendingEmail() async {
    final user = _auth.currentUser;
    final pendingEmail = _pendingEmail;

    if (user == null || pendingEmail == null) return;

    setState(() {
      _resendingPendingEmail = true;
    });

    final sent = await _updateEmailWithReauth(user, pendingEmail);

    if (!mounted) return;

    setState(() {
      _resendingPendingEmail = false;
    });

    if (sent) {
      _showMessage('Confirmation email resent to $pendingEmail.', Colors.green);
    }
  }

  // ============================================================
  // UPDATE EMAIL (WITH RE-AUTH IF FIREBASE REQUIRES IT)
  // ============================================================

  Future<bool> _updateEmailWithReauth(User user, String newEmail) async {
    try {
      await user.verifyBeforeUpdateEmail(newEmail);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        if (!mounted) return false;
        _showMessage(_emailErrorMessage(e), Colors.red);
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      _showErrorDialog('Unable to update your email', e);
      return false;
    }

    final reauthenticated = await _showReauthDialog(user);

    if (!reauthenticated) {
      return false;
    }

    try {
      await user.verifyBeforeUpdateEmail(newEmail);
      return true;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return false;

      _showMessage(_emailErrorMessage(e), Colors.red);
      return false;
    } catch (e) {
      if (!mounted) return false;
      _showErrorDialog('Unable to update your email', e);
      return false;
    }
  }

  // ============================================================
  // RE-AUTH DIALOG
  // ============================================================

  Future<bool> _showReauthDialog(User user) async {
    final passwordController = TextEditingController();
    bool obscure = true;
    bool submitting = false;
    String? error;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Confirm Your Password',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'For your security, please re-enter your '
                    'password to change your email.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    autofocus: true,
                    enabled: !submitting,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      errorText: error,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          final password = passwordController.text;

                          if (password.isEmpty) {
                            setDialogState(() {
                              error = 'Enter your password.';
                            });
                            return;
                          }

                          setDialogState(() {
                            submitting = true;
                            error = null;
                          });

                          try {
                            final credential = EmailAuthProvider.credential(
                              email: user.email ?? '',
                              password: password,
                            );

                            await user.reauthenticateWithCredential(credential);

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } on FirebaseAuthException catch (e) {
                            setDialogState(() {
                              submitting = false;
                              error =
                                  (e.code == 'wrong-password' ||
                                      e.code == 'invalid-credential')
                                  ? 'Incorrect password.'
                                  : (e.message ?? 'Failed to verify password.');
                            });
                          } catch (_) {
                            setDialogState(() {
                              submitting = false;
                              error = 'Failed to verify password.';
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();

    return confirmed ?? false;
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'You have been signed out. Please log in again.',
        Colors.red,
      );
      return;
    }

    if (_fullNameController.text.trim().isEmpty) {
      _showMessage('Full name is required.', Colors.red);
      return;
    }

    if (_selectedMunicipality == null) {
      _showMessage('Please select your branch (municipality).', Colors.red);
      return;
    }

    if (!isValidSorsogonSecondDistrictMunicipality(_selectedMunicipality!)) {
      _showMessage(
        'Selected municipality is not part of Sorsogon 2nd District.',
        Colors.red,
      );
      return;
    }

    final newEmail = _emailController.text.trim();

    if (newEmail.isEmpty) {
      _showMessage('Email is required.', Colors.red);
      return;
    }

    if (!newEmail.contains('@')) {
      _showMessage('Enter a valid email address.', Colors.red);
      return;
    }

    final currentAuthEmail = user.email ?? '';

    final emailChanged =
        newEmail.toLowerCase() != currentAuthEmail.toLowerCase();

    setState(() {
      _savingProfile = true;
    });

    // ==========================================================
    // CHECK EMAIL ISN'T ALREADY TAKEN
    //
    // Firebase's "Email Enumeration Protection" makes
    // `verifyBeforeUpdateEmail` silently succeed even when the
    // address belongs to another account — no exception, no email
    // actually sent. Check our own Firestore copy first so this
    // shows up as an immediate, clear error.
    // ==========================================================

    if (emailChanged) {
      try {
        final existing = await _firestore
            .collection('users')
            .where('email', isEqualTo: newEmail)
            .limit(1)
            .get();

        final takenByAnotherUser = existing.docs.any(
          (doc) => doc.id != user.uid,
        );

        if (takenByAnotherUser) {
          if (!mounted) return;

          setState(() {
            _savingProfile = false;
          });

          _showMessage(
            'That email is already used by another account.',
            Colors.red,
          );

          return;
        }
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _savingProfile = false;
        });

        _showErrorDialog('Unable to verify that email', e);

        return;
      }
    }

    // ==========================================================
    // UPDATE SIGN-IN EMAIL (IF CHANGED)
    // ==========================================================

    if (emailChanged) {
      final emailUpdateStarted = await _updateEmailWithReauth(user, newEmail);

      if (!emailUpdateStarted) {
        if (!mounted) return;

        setState(() {
          _savingProfile = false;
        });

        return;
      }

      // Keep the field showing the still-current email until the
      // consumer confirms the change via the link.
      _emailController.text = currentAuthEmail;
    }

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'full_name': _fullNameController.text.trim(),

        'email': currentAuthEmail,

        if (emailChanged) 'pendingEmail': newEmail,

        'municipality': _selectedMunicipality,

        'uid': user.uid,
        'user_type': widget.userTypeValue,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      final navigator = Navigator.of(context);

      setState(() {
        _editingProfile = false;
        _savingProfile = false;
      });

      if (emailChanged) {
        await navigator.push<bool>(
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(pendingEmail: newEmail),
          ),
        );

        await _loadProfile();
      } else {
        _showMessage('Profile updated successfully.', Colors.green);
      }
    } catch (e) {
      debugPrint('Error saving staff profile: $e');

      if (!mounted) return;

      setState(() {
        _savingProfile = false;
      });

      _showErrorDialog('Unable to save your profile', e);
    }
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> _changePassword() async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'You have been signed out. Please log in again.',
        Colors.red,
      );
      return;
    }

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty) {
      _showMessage('Enter your current password.', Colors.red);
      return;
    }

    if (newPassword.length < 6) {
      _showMessage('New password must be at least 6 characters.', Colors.red);
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage("New passwords don't match.", Colors.red);
      return;
    }

    setState(() {
      _changingPassword = true;
    });

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email ?? '',
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      if (!mounted) return;

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _changingPassword = false;
      });

      _showMessage('Password updated successfully.', Colors.green);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _changingPassword = false;
      });

      String message;

      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Current password is incorrect.';
          break;
        case 'weak-password':
          message = 'New password is too weak.';
          break;
        default:
          message = e.message ?? 'Unable to update password.';
      }

      _showMessage(message, Colors.red);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _changingPassword = false;
      });

      _showErrorDialog('Unable to update password', e);
    }
  }

  // ============================================================
  // PROFILE FIELD
  // ============================================================

  Widget _profileField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool enabled = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _accent, size: 21),
          filled: true,
          fillColor: enabled ? Colors.white : const Color(0xFFF5F7F5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PASSWORD FIELD
  // ============================================================

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enabled: !_changingPassword,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.lock_outline, color: _accent, size: 21),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
            ),
            onPressed: onToggleObscure,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MUNICIPALITY DROPDOWN (BRANCH)
  // ============================================================

  Widget _municipalityDropdown() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _editingProfile ? Colors.white : const Color(0xFFF5F7F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _editingProfile
              ? _accent.withValues(alpha: 0.35)
              : Colors.grey.shade200,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMunicipality,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: _accent),
          hint: Row(
            children: [
              Icon(
                Icons.store_mall_directory_outlined,
                color: _accent,
                size: 21,
              ),
              const SizedBox(width: 12),
              Text(
                'Select Branch (Municipality)',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          selectedItemBuilder: (context) {
            return _municipalities.map((item) {
              return Row(
                children: [
                  Icon(
                    Icons.store_mall_directory_outlined,
                    color: _accent,
                    size: 21,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              );
            }).toList();
          },
          items: _municipalities.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: _editingProfile
              ? (value) {
                  setState(() {
                    _selectedMunicipality = value;
                  });
                }
              : null,
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT BUTTON
  // ============================================================

  Widget _logoutButton() {
    return Listener(
      onPointerDown: (_) => setState(() => _logoutButtonPressed = true),
      onPointerUp: (_) => setState(() => _logoutButtonPressed = false),
      onPointerCancel: (_) => setState(() => _logoutButtonPressed = false),
      child: AnimatedScale(
        scale: _logoutButtonPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: Icon(Icons.logout, size: 19, color: Colors.red.shade600),
            label: Text(
              'Log Out',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
                color: Colors.red.shade600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.red.shade200),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text('${widget.role} Profile'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('You have been signed out.'))
          : !_profileLoaded
          ? Center(child: CircularProgressIndicator(color: _accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // HEADER
                  // ==================================================

                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .12),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: _accent.withValues(alpha: .25),
                          blurRadius: 15,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.badge_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _fullNameController.text.trim().isNotEmpty
                                    ? _fullNameController.text.trim()
                                    : widget.role,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.role.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // DETAILS CARD
                  // ==================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.account_circle_outlined,
                              color: Colors.black87,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (!_editingProfile)
                              IconButton(
                                tooltip: 'Edit Profile',
                                splashRadius: 20,
                                onPressed: () {
                                  setState(() => _editingProfile = true);
                                },
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.black87,
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ==========================================
                        // PENDING EMAIL CHANGE REMINDER
                        // ==========================================
                        if (_pendingEmail != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.mark_email_unread_outlined,
                                      size: 18,
                                      color: Colors.orange.shade800,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Email change pending: confirm '
                                        '$_pendingEmail via the link we '
                                        'sent, or resend it below.',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.orange.shade900,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              Colors.orange.shade900,
                                          side: BorderSide(
                                            color: Colors.orange.shade300,
                                          ),
                                        ),
                                        onPressed: _resendingPendingEmail
                                            ? null
                                            : _resendPendingEmail,
                                        child: _resendingPendingEmail
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Text('Resend Email'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _accent,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () async {
                                          await Navigator.of(
                                            context,
                                          ).push<bool>(
                                            MaterialPageRoute(
                                              builder: (_) => VerifyEmailScreen(
                                                pendingEmail: _pendingEmail,
                                              ),
                                            ),
                                          );

                                          await _loadProfile();
                                        },
                                        child: const Text('Check Status'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // ==========================================
                        // EMAIL
                        // ==========================================
                        _profileField(
                          label: 'Email',
                          icon: Icons.email_outlined,
                          controller: _emailController,
                          enabled: _editingProfile,
                          keyboardType: TextInputType.emailAddress,
                        ),

                        // ==========================================
                        // FULL NAME
                        // ==========================================
                        _profileField(
                          label: 'Full Name',
                          icon: Icons.person_outline,
                          controller: _fullNameController,
                          enabled: _editingProfile,
                        ),

                        // ==========================================
                        // BRANCH (MUNICIPALITY)
                        // ==========================================
                        const SizedBox(height: 2),

                        Text(
                          'Branch',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 8),

                        _municipalityDropdown(),

                        // ==========================================
                        // SAVE / CANCEL
                        // ==========================================
                        if (_editingProfile)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _savingProfile
                                      ? null
                                      : () async {
                                          await _loadProfile();

                                          if (mounted) {
                                            setState(
                                              () => _editingProfile = false,
                                            );
                                          }
                                        },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    side: BorderSide(
                                      color: Colors.grey.shade400,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Listener(
                                  onPointerDown: (_) {
                                    if (!_savingProfile) {
                                      setState(() => _saveButtonPressed = true);
                                    }
                                  },
                                  onPointerUp: (_) => setState(
                                    () => _saveButtonPressed = false,
                                  ),
                                  onPointerCancel: (_) => setState(
                                    () => _saveButtonPressed = false,
                                  ),
                                  child: AnimatedScale(
                                    scale: _saveButtonPressed ? 0.97 : 1.0,
                                    duration: const Duration(milliseconds: 120),
                                    curve: Curves.easeOut,
                                    child: ElevatedButton(
                                      onPressed: _savingProfile
                                          ? null
                                          : _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _accent,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: _savingProfile
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Save Changes',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        if (!_editingProfile)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              'Firebase UID: ${user.uid}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // CHANGE PASSWORD CARD
                  // ==================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_reset_outlined,
                              color: Colors.black87,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Change Password',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'For your security, confirm your current '
                          'password before setting a new one.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 14),

                        _passwordField(
                          label: 'Current Password',
                          controller: _currentPasswordController,
                          obscure: _obscureCurrentPassword,
                          onToggleObscure: () => setState(
                            () => _obscureCurrentPassword =
                                !_obscureCurrentPassword,
                          ),
                        ),

                        _passwordField(
                          label: 'New Password',
                          controller: _newPasswordController,
                          obscure: _obscureNewPassword,
                          onToggleObscure: () => setState(
                            () => _obscureNewPassword = !_obscureNewPassword,
                          ),
                        ),

                        _passwordField(
                          label: 'Confirm New Password',
                          controller: _confirmPasswordController,
                          obscure: _obscureConfirmPassword,
                          onToggleObscure: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),

                        const SizedBox(height: 4),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _changingPassword
                                ? null
                                : _changePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _changingPassword
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Update Password',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // LOGOUT
                  // ==================================================

                  _logoutButton(),
                ],
              ),
            ),
    );
  }
}
