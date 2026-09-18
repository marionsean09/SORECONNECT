import 'package:flutter/material.dart';

// ============================================================
// SMOOTH PAGE ROUTE
//
// A shared slide + fade transition for pushing a new screen,
// using the same strong ease-out curve already used for on-screen
// entrance animations elsewhere in the app. Reused across screens
// so navigating between them feels like one cohesive motion
// language instead of the default abrupt platform transition.
// Popping the route automatically reverses the same animation, so
// back navigation stays predictable.
// ============================================================

const Curve pageTransitionCurve = Cubic(0.23, 1, 0.32, 1);

Route<T> smoothPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: pageTransitionCurve,
      );

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
