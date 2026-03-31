import 'package:flutter/material.dart';

/// Drop-in replacement for [MaterialPageRoute] that uses a fade + subtle
/// upward-slide transition (300 ms, easeOutCubic) instead of the platform
/// default slide-in. Usage is identical:
///
/// ```dart
/// Navigator.push(context, AppRoute(builder: (_) => MyScreen()));
/// ```
class AppRoute<T> extends PageRouteBuilder<T> {
  AppRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
