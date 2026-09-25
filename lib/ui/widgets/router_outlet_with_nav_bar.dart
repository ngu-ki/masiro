import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/platform.dart';
import 'package:masiro/misc/tray_icon.dart';
import 'package:masiro/ui/widgets/adaptive_status_bar_style.dart';
import 'package:masiro/ui/widgets/nav_bar.dart';

bool _systemTrayInitialized = false;

class RouterOutletWithNavBar extends StatefulWidget {
  const RouterOutletWithNavBar({required this.child, super.key});

  /// The widget to display in the body of the Scaffold.
  final Widget child;

  @override
  State<RouterOutletWithNavBar> createState() => _RouterOutletWithNavBarState();
}

class _RouterOutletWithNavBarState extends State<RouterOutletWithNavBar> {
  /// Whether the "swipe back again to exit" hint is currently shown.
  bool _exitHintVisible = false;

  Timer? _exitHintTimer;

  @override
  void initState() {
    super.initState();
    _initSystemTray();
  }

  @override
  void dispose() {
    _exitHintTimer?.cancel();
    super.dispose();
  }

  void _handleBackGesture() {
    if (_exitHintVisible) {
      SystemNavigator.pop();
      return;
    }
    setState(() {
      _exitHintVisible = true;
    });
    _exitHintTimer?.cancel();
    _exitHintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _exitHintVisible = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      bottomNavigationBar: isMobilePhone
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildExitHint(context),
                const NavBar(),
              ],
            )
          : null,
      body: isDesktop
          ? Row(
              children: [
                const NavBar(),
                const VerticalDivider(
                  thickness: 0.0,
                  width: 1.0,
                ),
                Expanded(child: Center(child: widget.child)),
              ],
            )
          : AdaptiveStatusBarStyle(
              child: widget.child,
            ),
    );

    if (!isMobilePhone) {
      return scaffold;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _handleBackGesture();
      },
      child: scaffold,
    );
  }

  Widget _buildExitHint(BuildContext context) {
    final localizations = context.localizations();
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: _exitHintVisible
          ? Container(
              width: double.infinity,
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Text(
                localizations.exitAppHint,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }

  void _initSystemTray() {
    if (!isDesktop) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_systemTrayInitialized) {
        return;
      }
      initSystemTray(context);
      _systemTrayInitialized = true;
    });
  }
}
