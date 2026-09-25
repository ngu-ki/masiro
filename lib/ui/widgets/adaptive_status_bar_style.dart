import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdaptiveStatusBarStyle extends StatelessWidget {
  const AdaptiveStatusBarStyle({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final iconBrightness = Theme.of(context).brightness == Brightness.light
        ? Brightness.dark
        : Brightness.light;
    // Use a declarative AnnotatedRegion instead of the imperative
    // SystemChrome.setSystemUIOverlayStyle. The reader page also uses
    // AnnotatedRegion, so when it is popped this region automatically
    // restores the main interface's status bar style instead of leaving
    // the reader's (e.g. light icons in night mode) behind.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
      ),
      child: child,
    );
  }
}
