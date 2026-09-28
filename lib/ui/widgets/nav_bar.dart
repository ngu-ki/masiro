import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:masiro/misc/context.dart';
import 'package:masiro/misc/platform.dart';

class NavBar extends StatelessWidget {
  const NavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // When tapping the already-active tab, reset to its initial location
    // (pops any pushed routes within that branch); otherwise switch to the
    // target branch, preserving its navigation stack.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return isDesktop
        ? buildNavigationRail(context)
        : buildNavigationBar(context);
  }

  Widget buildNavigationRail(BuildContext context) {
    final localizations = context.localizations();
    return NavigationRail(
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.explore_outlined),
          selectedIcon: const Icon(Icons.explore),
          label: Text(localizations.home),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.menu_book_outlined),
          selectedIcon: const Icon(Icons.menu_book),
          label: Text(localizations.favorites),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.person_outline_rounded),
          selectedIcon: const Icon(Icons.person_rounded),
          label: Text(localizations.more),
        ),
      ],
      labelType: NavigationRailLabelType.all,
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: _onDestinationSelected,
    );
  }

  Widget buildNavigationBar(BuildContext context) {
    final localizations = context.localizations();
    return NavigationBar(
      height: 60,
      backgroundColor: context.navBarColor(),
      onDestinationSelected: _onDestinationSelected,
      selectedIndex: navigationShell.currentIndex,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.explore_outlined),
          selectedIcon: const Icon(Icons.explore),
          label: localizations.home,
        ),
        NavigationDestination(
          icon: const Icon(Icons.menu_book_outlined),
          selectedIcon: const Icon(Icons.menu_book),
          label: localizations.favorites,
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline_rounded),
          selectedIcon: const Icon(Icons.person_rounded),
          label: localizations.more,
        ),
      ],
    );
  }
}
