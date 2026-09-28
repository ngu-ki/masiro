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

/// Exposes a [ValueNotifier] tracking the active branch index so descendants
/// can listen to tab switches (e.g. the discovery tab resets its search when
/// it becomes inactive).
class ActiveBranchNotifier extends InheritedWidget {
  final ValueNotifier<int> notifier;

  const ActiveBranchNotifier({
    required this.notifier,
    required super.child,
  });

  static ValueNotifier<int>? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ActiveBranchNotifier>()
        ?.notifier;
  }

  @override
  bool updateShouldNotify(covariant ActiveBranchNotifier oldWidget) => false;
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

  /// Tracks the active branch index; updated by the NavBar on every tab
  /// switch so descendants can listen without StatefulNavigationShell being
  /// a Listenable.
  late final ValueNotifier<int> _activeBranchNotifier;

  @override
  void initState() {
    super.initState();
    _activeBranchNotifier =
        ValueNotifier<int>(widget.navigationShell.currentIndex);
    _initSystemTray();
  }

  @override
  void dispose() {
    _activeBranchNotifier.dispose();
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
                NavBar(
                  navigationShell: navigationShell,
                  activeBranchNotifier: _activeBranchNotifier,
                ),
              ],
            )
          : null,
      body: isDesktop
          ? Row(
              children: [
                NavBar(
                  navigationShell: navigationShell,
                  activeBranchNotifier: _activeBranchNotifier,
                ),
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

    final child = isMobilePhone
        ? PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) {
                return;
              }
              _handleBackGesture();
            },
            child: scaffold,
          )
        : scaffold;

    return ActiveBranchNotifier(
      notifier: _activeBranchNotifier,
      child: child,
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
