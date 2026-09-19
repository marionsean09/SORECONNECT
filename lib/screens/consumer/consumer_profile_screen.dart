import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:soreconnect/data/sorsogon_address_data.dart';
import 'package:soreconnect/screens/auth/login_screen.dart';
import 'package:soreconnect/screens/auth/verify_email_screen.dart';

// ============================================================
// CONSUMER PROFILE SCREEN
//
// Moved out of the dashboard's inline accordion. That accordion
// lived inside the dashboard's nested bill/complaint StreamBuilders
// (which use inline, per-build `stream:` values), so any snapshot
// emission there rebuilt the whole profile subtree mid-edit —
// dropping keyboard focus/cursor position while typing and making
// saves feel unreliable. As its own screen with its own State, its
// rebuilds are driven only by its own fields, never by the
// dashboard's unrelated streams.
// ============================================================

class ConsumerProfileScreen extends StatefulWidget {
  const ConsumerProfileScreen({super.key});

  @override
  State<ConsumerProfileScreen> createState() =>
      _ConsumerProfileScreenState();
}

class _ConsumerProfileScreenState extends State<ConsumerProfileScreen>
    with AutomaticKeepAliveClientMixin {
  // Keeps this tab's state (edit mode, unsaved field edits) alive
  // when swiping to another bottom-nav tab, instead of disposing
  // and rebuilding from scratch each time.
  @override
  bool get wantKeepAlive => true;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static const orange = Color(0xFFFFA000);
  static const background = Color(0xFFF5F7F5);

  // ============================================================
  // PROFILE CONTROLLERS
  // ============================================================

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _meterNumberController = TextEditingController();
  final _contactNumberController = TextEditingController();

  // ============================================================
  // ADDRESS
  // ============================================================

  String? _selectedMunicipality;
  String? _selectedBarangay;

  // The municipality as loaded from Firestore — once set, it's
  // locked (only barangay stays editable), since a consumer's
  // municipality also drives which branch's staff handle their
  // account. Null only means "not yet set."
  String? _originalMunicipality;

  // ============================================================
  // PROFILE STATE
  // ============================================================

  bool _editingProfile = false;
  bool _savingProfile = false;
  bool _profileLoaded = false;
  bool _saveButtonPressed = false;
  bool _logoutButtonPressed = false;

  // An email change the consumer has started (Firebase sent a
  // confirmation link) but not yet confirmed by tapping it. Kept in
  // Firestore, not just in-memory, so it still shows up as a
  // reminder even if the consumer closed the app before confirming.
  String? _pendingEmail;
  bool _resendingPendingEmail = false;

  // The account number as loaded from Firestore, so saving other
  // fields doesn't get blocked by the 8-digit format rule for
  // consumers whose existing (pre-rule) account number isn't 8
  // digits — the rule only applies once they actually change it.
  String _originalAccountNumber = '';

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
    _accountNumberController.dispose();
    _meterNumberController.dispose();
    _contactNumberController.dispose();

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

  // ============================================================
  // ERROR DIALOG
  //
  // Shows the actual exception text (e.g. a Firestore
  // "permission-denied" from security rules), not just a generic
  // "something went wrong" — a SnackBar truncates/auto-dismisses
  // too fast to read a real error, and a vague message makes it
  // impossible to tell a rules rejection apart from a network
  // problem or anything else.
  // ============================================================

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
  // ADDRESS HELPERS
  // ============================================================

  List<String> get _municipalities {
    return getSorsogonSecondDistrictMunicipalities();
  }

  List<String> get _barangays {
    return getBarangaysForMunicipality(_selectedMunicipality);
  }

  String _buildAddress() {
    if (_selectedMunicipality == null || _selectedBarangay == null) {
      return '';
    }

    return buildSorsogonAddress(
      municipality: _selectedMunicipality!,
      barangay: _selectedBarangay!,
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

      _accountNumberController.text =
          data['accountNumber']?.toString() ?? '';

      _originalAccountNumber = _accountNumberController.text;

      _meterNumberController.text =
          data['meterNumber']?.toString() ?? '';

      _contactNumberController.text =
          data['contactNumber']?.toString() ?? '';

      final pendingEmail = data['pendingEmail']?.toString();

      // A pending email only means anything while it still differs
      // from the actual sign-in email — if Auth's email already
      // caught up (e.g. Firestore's cache just hadn't cleared it
      // yet), treat it as already resolved.
      _pendingEmail = (pendingEmail != null &&
              pendingEmail.isNotEmpty &&
              pendingEmail.toLowerCase() != (user.email ?? '').toLowerCase())
          ? pendingEmail
          : null;

      // ========================================================
      // LOAD MUNICIPALITY
      // ========================================================

      String? municipality = data['municipality']?.toString();

      if (municipality != null && !_municipalities.contains(municipality)) {
        municipality = null;
      }

      // ========================================================
      // LOAD BARANGAY
      // ========================================================

      String? barangay = data['barangay']?.toString();

      if (municipality != null) {
        final availableBarangays = getBarangaysForMunicipality(municipality);

        if (!availableBarangays.contains(barangay)) {
          barangay = null;
        }
      } else {
        barangay = null;
      }

      // ========================================================
      // FALLBACK:
      // TRY TO READ OLD ADDRESS FIELD
      // ========================================================

      if (municipality == null || barangay == null) {
        final oldAddress = data['address']?.toString() ?? '';

        _parseOldAddress(oldAddress);

        municipality ??= _selectedMunicipality;
        barangay ??= _selectedBarangay;
      }

      if (mounted) {
        setState(() {
          _selectedMunicipality = municipality;
          _originalMunicipality = municipality;
          _selectedBarangay = barangay;
          _profileLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');

      if (!mounted) return;

      setState(() {
        _profileLoaded = true;
      });

      _showErrorDialog('Unable to load your profile', e);
    }
  }

  // ============================================================
  // PARSE OLD ADDRESS
  // ============================================================

  void _parseOldAddress(String address) {
    if (address.trim().isEmpty) {
      return;
    }

    final parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length < 2) {
      return;
    }

    final possibleBarangay = parts[0];
    final possibleMunicipality = parts[1];

    if (_municipalities.contains(possibleMunicipality)) {
      final barangays = getBarangaysForMunicipality(possibleMunicipality);

      if (barangays.contains(possibleBarangay)) {
        _selectedMunicipality = possibleMunicipality;
        _selectedBarangay = possibleBarangay;
      }
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
      _showMessage(
        'Confirmation email resent to $pendingEmail.',
        Colors.green,
      );
    }
  }

  // ============================================================
  // UPDATE EMAIL (WITH RE-AUTH IF FIREBASE REQUIRES IT)
  //
  // Changing the sign-in email is a "sensitive" operation — Firebase
  // rejects it with `requires-recent-login` once the session has
  // been open for a while (very common on a phone where the app
  // just stays logged in for days). Prompt for the password right
  // here and retry once automatically instead of just failing.
  //
  // Both catch blocks use a broad `catch (e)` fallback alongside the
  // narrower `on FirebaseAuthException` one — a non-auth exception
  // here (a raw platform/network error, for instance) used to
  // propagate straight out of `_saveProfile()` uncaught, which
  // Flutter swallows silently in release builds: no error dialog, no
  // success message, just a permanently stuck "Saving..." button.
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
                    backgroundColor: orange,
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
                            final credential =
                                EmailAuthProvider.credential(
                              email: user.email ?? '',
                              password: password,
                            );

                            await user.reauthenticateWithCredential(
                              credential,
                            );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } on FirebaseAuthException catch (e) {
                            setDialogState(() {
                              submitting = false;
                              error = (e.code == 'wrong-password' ||
                                      e.code == 'invalid-credential')
                                  ? 'Incorrect password.'
                                  : (e.message ??
                                      'Failed to verify password.');
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
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
  // PROPAGATE METER NUMBER UPDATES ACROSS ACCOUNT RECORDS
  // ============================================================

  Future<void> _syncMeterNumberAcrossAccountRecords({
    required String uid,
    required String accountNumber,
    required String newMeterNumber,
  }) async {
    final normalizedMeterNumber = newMeterNumber.trim();

    if (uid.isEmpty || normalizedMeterNumber.isEmpty) {
      return;
    }

    try {
      final refs = <DocumentReference>{};

      final billDocsByConsumer = await _firestore
          .collection('bills')
          .where('consumerId', isEqualTo: uid)
          .get();

      for (final doc in billDocsByConsumer.docs) {
        refs.add(doc.reference);
      }

      if (accountNumber.trim().isNotEmpty) {
        final billDocsByAccount = await _firestore
            .collection('bills')
            .where('accountNumber', isEqualTo: accountNumber.trim())
            .get();

        for (final doc in billDocsByAccount.docs) {
          refs.add(doc.reference);
        }
      }

      final readingDocsByConsumer = await _firestore
          .collection('meter_readings')
          .where('consumerId', isEqualTo: uid)
          .get();

      for (final doc in readingDocsByConsumer.docs) {
        refs.add(doc.reference);
      }

      if (accountNumber.trim().isNotEmpty) {
        final readingDocsByAccount = await _firestore
            .collection('meter_readings')
            .where('accountNumber', isEqualTo: accountNumber.trim())
            .get();

        for (final doc in readingDocsByAccount.docs) {
          refs.add(doc.reference);
        }
      }

      if (refs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();

      for (final ref in refs) {
        batch.update(
          ref,
          {
            'meterNumber': normalizedMeterNumber,
            'meter_number': normalizedMeterNumber,
            'meterNo': normalizedMeterNumber,
          },
        );
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error syncing meter number across account records: $e');
    }
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

    // ========================================================
    // BASIC VALIDATION
    // ========================================================

    if (_fullNameController.text.trim().isEmpty) {
      _showMessage('Full name is required.', Colors.red);
      return;
    }

    final accountNumberChanged =
        _accountNumberController.text.trim() != _originalAccountNumber;

    if (accountNumberChanged &&
        !RegExp(r'^\d{8}$')
            .hasMatch(_accountNumberController.text.trim())) {
      _showMessage(
        'Account number must be exactly 8 digits.',
        Colors.red,
      );
      return;
    }

    if (_meterNumberController.text.trim().isEmpty) {
      _showMessage('Meter number is required.', Colors.red);
      return;
    }

    if (_contactNumberController.text.trim().isEmpty) {
      _showMessage('Contact number is required.', Colors.red);
      return;
    }

    // ========================================================
    // ADDRESS VALIDATION
    // ========================================================

    if (_selectedMunicipality == null) {
      _showMessage('Please select your municipality.', Colors.red);
      return;
    }

    if (_selectedBarangay == null) {
      _showMessage('Please select your barangay.', Colors.red);
      return;
    }

    if (!isValidSorsogonSecondDistrictMunicipality(_selectedMunicipality!)) {
      _showMessage(
        'Selected municipality is not part of Sorsogon 2nd District.',
        Colors.red,
      );
      return;
    }

    if (!isValidBarangayForMunicipality(
      municipality: _selectedMunicipality!,
      barangay: _selectedBarangay!,
    )) {
      _showMessage(
        'Selected barangay does not belong to the selected municipality.',
        Colors.red,
      );
      return;
    }

    final address = _buildAddress();

    if (address.isEmpty) {
      _showMessage('Please complete your address.', Colors.red);
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
    // Firebase's "Email Enumeration Protection" (on by default for
    // newer projects) makes `verifyBeforeUpdateEmail` silently
    // succeed even when the address belongs to another account —
    // no exception, no email actually sent, just a dead end. Since
    // Firebase itself won't tell us anymore, check our own Firestore
    // copy first so this shows up as an immediate, clear error
    // instead of a link that never arrives.
    // ==========================================================

    if (emailChanged) {
      try {
        final existing = await _firestore
            .collection('users')
            .where('email', isEqualTo: newEmail)
            .limit(1)
            .get();

        final takenByAnotherUser =
            existing.docs.any((doc) => doc.id != user.uid);

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
    //
    // Firebase sends a confirmation link to the NEW address —
    // the sign-in email only actually changes once the user taps
    // it, so Firestore keeps the CURRENT (still-valid) email
    // until then.
    // ==========================================================

    if (emailChanged) {
      final emailUpdateStarted = await _updateEmailWithReauth(
        user,
        newEmail,
      );

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
      final newMeterNumber = _meterNumberController.text.trim();

      await _firestore.collection('users').doc(user.uid).set(
        {
          'full_name': _fullNameController.text.trim(),

          'email': currentAuthEmail,

          // Persisted (not just in-memory) so a pending email
          // change still shows up as a reminder even if the
          // consumer closes the app before confirming it. Left out
          // entirely (not touched) when this save didn't change the
          // email, so an earlier still-unconfirmed change survives
          // unrelated profile edits.
          if (emailChanged) 'pendingEmail': newEmail,

          'accountNumber': _accountNumberController.text.trim(),

          'meterNumber': newMeterNumber,
          'meter_number': newMeterNumber,

          'contactNumber': _contactNumberController.text.trim(),

          // ==================================================
          // NEW STRUCTURED ADDRESS
          // ==================================================

          'province': sorsogonProvince,
          'district': sorsogonSecondDistrict,
          'municipality': _selectedMunicipality,
          'barangay': _selectedBarangay,

          // ==================================================
          // COMPLETE READABLE ADDRESS
          // ==================================================

          'address': address,

          'uid': user.uid,
          'user_type': 'consumer',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      final navigator = Navigator.of(context);

      await _syncMeterNumberAcrossAccountRecords(
        uid: user.uid,
        accountNumber: _accountNumberController.text.trim(),
        newMeterNumber: _meterNumberController.text.trim(),
      );

      setState(() {
        _editingProfile = false;
        _savingProfile = false;
      });

      if (emailChanged) {
        // No SnackBar here — the screen we're about to push already
        // shows this same "confirm your new email" messaging, and a
        // SnackBar fired right before a Navigator.push gets covered
        // by the new screen before it's ever visible.

        // Once the consumer confirms the new email on that screen,
        // it syncs Firestore itself, signs out, and sends them to
        // Login — this only returns here if they back out without
        // confirming.
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
      debugPrint('Error saving profile: $e');

      if (!mounted) return;

      setState(() {
        _savingProfile = false;
      });

      _showErrorDialog('Unable to save your profile', e);
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
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: orange, size: 21),
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
            borderSide: const BorderSide(color: orange, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ADDRESS DROPDOWN FIELD
  // ============================================================

  Widget _addressDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    bool enabled = true,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF5F7F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? orange.withValues(alpha: 0.35) : Colors.grey.shade200,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1 : 0.4,
            child: const Icon(Icons.keyboard_arrow_down, color: orange),
          ),
          hint: Row(
            children: [
              Icon(icon, color: orange, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    label,
                    key: ValueKey(label),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          selectedItemBuilder: (context) {
            return items.map((item) {
              return Row(
                children: [
                  Icon(icon, color: orange, size: 21),
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
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  // ============================================================
  // ADDRESS SECTION
  // ============================================================

  Widget _addressSection() {
    final address = _buildAddress();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ======================================================
        // MUNICIPALITY
        // ======================================================

        _addressDropdown(
          label: 'Select Municipality',
          icon: Icons.location_city_outlined,
          value: _selectedMunicipality,
          items: _municipalities,
          // Once a municipality has been saved, it's locked — only
          // barangay stays editable, since municipality also
          // determines which branch's staff handle this account.
          enabled: _editingProfile && _originalMunicipality == null,
          onChanged: (value) {
            setState(() {
              _selectedMunicipality = value;

              // Reset barangay whenever municipality changes.
              _selectedBarangay = null;
            });
          },
        ),

        if (_originalMunicipality != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Your municipality is locked once set.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),

        // ======================================================
        // BARANGAY
        // ======================================================

        _addressDropdown(
          label: _selectedMunicipality == null
              ? 'Select municipality first'
              : 'Select Barangay',
          icon: Icons.location_on_outlined,
          value: _selectedBarangay,
          items: _barangays,
          enabled: _editingProfile && _selectedMunicipality != null,
          onChanged: (value) {
            setState(() {
              _selectedBarangay = value;
            });
          },
        ),

        // ======================================================
        // ADDRESS PREVIEW
        // ======================================================

        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.home_outlined, color: orange, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete Address',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.isNotEmpty
                          ? address
                          : 'Select municipality and barangay',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: address.isNotEmpty
                            ? Colors.black87
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
        title: const Text('My Profile'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('You have been signed out.'))
          : !_profileLoaded
              ? const Center(
                  child: CircularProgressIndicator(color: orange),
                )
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
                          color: orange,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .12),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: orange.withValues(alpha: .25),
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
                                Icons.person_outline,
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
                                        : 'Consumer',
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
                                    _accountNumberController.text
                                            .trim()
                                            .isNotEmpty
                                        ? 'Account No. '
                                            '${_accountNumberController.text.trim()}'
                                        : 'CONSUMER ACCOUNT',
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
                            // ==========================================
                            // HEADER
                            // ==========================================

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
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                color:
                                                    Colors.orange.shade300,
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
                                              backgroundColor: orange,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () async {
                                              await Navigator.of(context)
                                                  .push<bool>(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      VerifyEmailScreen(
                                                    pendingEmail:
                                                        _pendingEmail,
                                                  ),
                                                ),
                                              );

                                              await _loadProfile();
                                            },
                                            child: const Text(
                                              'Check Status',
                                            ),
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
                            // ACCOUNT NUMBER
                            // ==========================================

                            _profileField(
                              label: 'Account Number (8 digits)',
                              icon: Icons.confirmation_number_outlined,
                              controller: _accountNumberController,
                              enabled: _editingProfile,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(8),
                              ],
                            ),

                            // ==========================================
                            // METER NUMBER
                            // ==========================================

                            _profileField(
                              label: 'Meter Number',
                              icon: Icons.speed_outlined,
                              controller: _meterNumberController,
                              enabled: _editingProfile,
                            ),

                            // ==========================================
                            // CONTACT NUMBER
                            // ==========================================

                            _profileField(
                              label: 'Contact Number',
                              icon: Icons.phone_outlined,
                              controller: _contactNumberController,
                              enabled: _editingProfile,
                              keyboardType: TextInputType.phone,
                            ),

                            // ==========================================
                            // ADDRESS
                            // ==========================================

                            const SizedBox(height: 2),

                            Text(
                              'Address',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 8),

                            _addressSection(),

                            // ==========================================
                            // ACCOUNT TYPE
                            // ==========================================

                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7F5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_outlined,
                                    color: Color(0xFF03C70D),
                                    size: 21,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Account Type',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: orange.withValues(alpha: .12),
                                      borderRadius:
                                          BorderRadius.circular(16),
                                    ),
                                    child: const Text(
                                      'CONSUMER',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

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
                                                  () => _editingProfile =
                                                      false,
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
                                          borderRadius:
                                              BorderRadius.circular(16),
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
                                          setState(
                                            () => _saveButtonPressed = true,
                                          );
                                        }
                                      },
                                      onPointerUp: (_) => setState(
                                        () => _saveButtonPressed = false,
                                      ),
                                      onPointerCancel: (_) => setState(
                                        () => _saveButtonPressed = false,
                                      ),
                                      child: AnimatedScale(
                                        scale: _saveButtonPressed
                                            ? 0.97
                                            : 1.0,
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        curve: Curves.easeOut,
                                        child: ElevatedButton(
                                          onPressed: _savingProfile
                                              ? null
                                              : _saveProfile,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: orange,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shadowColor: Colors.transparent,
                                            padding: const EdgeInsets
                                                .symmetric(vertical: 13),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: _savingProfile
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Text(
                                                  'Save Changes',
                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            // ==========================================
                            // FIREBASE UID
                            // ==========================================

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
