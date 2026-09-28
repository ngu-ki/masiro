import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/platform.dart';
import 'package:masiro/misc/tray_icon.dart';
import 'package:masiro/ui/widgets/adaptive_status_bar_style.dart';
import 'package:masiro/ui/widgets/nav_bar.dart';

bool _systemTrayInitialized = false;

/// Exposes the [StatefulNavigationShell] to descendants so they can listen
/// to tab switches (e.g. the discovery tab resets its search when inactive).
class NavigationShellData extends InheritedWidget {
  final StatefulNavigationShell navigationShell;

  const NavigationShellData({
    required this.navigationShell,
    required super.child,
  });

  static StatefulNavigationShell? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NavigationShellData>()
        ?.navigationShell;
  }

  @override
  bool updateShouldNotify(covariant NavigationShellData oldWidget) => false;
}

class RouterOutletWithNavBar extends StatefulWidget {
  const RouterOutletWithNavBar({required this.navigationShell, super.key});

  /// The stateful navigation shell that drives tab switching and keeps
  /// each branch's widget tree (and its blocs) alive across tab switches.
  final StatefulNavigationShell navigationShell;

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
    final navigationShell = widget.navigationShell;
    final scaffold = Scaffold(
      bottomNavigationBar: isMobilePhone
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildExitHint(context),
                NavBar(navigationShell: navigationShell),
              ],
            )
          : null,
      body: isDesktop
          ? Row(
              children: [
                NavBar(navigationShell: navigationShell),
                const VerticalDivider(
                  thickness: 0.0,
                  width: 1.0,
                ),
                Expanded(child: Center(child: navigationShell)),
              ],
            )
          : AdaptiveStatusBarStyle(
              child: navigationShell,
            ),
    );

    if (!isMobilePhone) {
      return NavigationShellData(
        navigationShell: navigationShell,
        child: scaffold,
      );
    }

    return NavigationShellData(
      navigationShell: navigationShell,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }
          _handleBackGesture();
        },
        child: scaffold,
      ),
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
