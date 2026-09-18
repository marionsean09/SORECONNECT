import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:soreconnect/screens/auth/login_screen.dart';

// ============================================================
// PENDING EMAIL GUARD
//
// `VerifyEmailScreen` only finalizes an email change (sync
// Firestore, sign out, send to Login) while it's actively on
// screen and polling. If the consumer/staff member backs out of
// that screen — or the app was backgrounded when they tapped the
// confirmation link in their email client — the change silently
// finishes on Firebase's side with nobody around to react to it:
// the dashboard just keeps showing the old session as if nothing
// happened.
//
// Call this from a dashboard's initState() as a safety net: it
// re-checks whether a pending email was confirmed since last seen,
// and if so, finishes the same sign-out/redirect the verify screen
// would have done.
// ============================================================

Future<void> checkPendingEmailConfirmed(BuildContext context) async {
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;

  if (user == null) return;

  try {
    await user.reload();
  } catch (_) {
    // Offline or transient — just skip this check, the dashboard
    // still works fine on the (possibly stale) cached session.
    return;
  }

  final refreshedUser = auth.currentUser;

  if (refreshedUser == null) return;

  Map<String, dynamic>? data;

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(refreshedUser.uid)
        .get();

    data = doc.data();
  } catch (_) {
    return;
  }

  final pendingEmail = data?['pendingEmail']?.toString();

  if (pendingEmail == null || pendingEmail.isEmpty) return;

  final confirmed = pendingEmail.toLowerCase() ==
      (refreshedUser.email ?? '').toLowerCase();

  if (!confirmed) return;

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(refreshedUser.uid)
        .set(
      {
        'email': pendingEmail,
        'pendingEmail': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
  } catch (_) {
    // Even if this write fails, the email change already happened
    // on Firebase's side — still sign out below so the consumer
    // isn't left signed in under a session that no longer matches
    // what they'll type at Login.
  }

  await auth.signOut();

  if (!context.mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => const LoginScreen(
        infoMessage:
            'Email updated. Please log in again with your new email.',
      ),
    ),
    (route) => false,
  );
}
