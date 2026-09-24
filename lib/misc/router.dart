import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:masiro/misc/cookie.dart';
import 'package:masiro/misc/platform.dart';
import 'package:masiro/ui/screens/about/about_screen.dart';
import 'package:masiro/ui/screens/comments/comments_screen.dart';
import 'package:masiro/ui/screens/error/error_screen.dart';
import 'package:masiro/ui/screens/favorites/favorites_screen.dart';
import 'package:masiro/ui/screens/license/license_screen.dart';
import 'package:masiro/ui/screens/licenses/licenses_screen.dart';
import 'package:masiro/ui/screens/login/login_screen.dart';
import 'package:masiro/ui/screens/novel/novel_screen.dart';
import 'package:masiro/ui/screens/reader/reader_screen.dart';
import 'package:masiro/ui/screens/search/search_screen.dart';
import 'package:masiro/ui/screens/settings/settings_screen.dart';
import 'package:masiro/ui/widgets/router_outlet_with_nav_bar.dart';

class RoutePath {
  static const String home = '/home';
  static const String favorites = '/favorites';
  static const String settings = '/settings';
  static const String login = '/login';
  static const String novel = '/novel';
  static const String reader = '/reader';
  static const String error = '/error';
  static const String search = '/search';
  static const String licenses = '/licenses';
  static const String license = '/license';
  static const String about = '/about';
  static const String comments = '/comments';
}

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Tab indices in the bottom navigation bar: 发现(home) -> 收藏 -> 我的.
const int _tabIndexHome = 0;
const int _tabIndexFavorites = 1;
const int _tabIndexSettings = 2;

/// The index of the tab currently displayed. It is updated while the
/// matching tab page is built and is used to decide the horizontal slide
/// direction when switching tabs. Starts at favorites (initialLocation).
int _currentTabIndex = _tabIndexFavorites;

/// Builds a tab page with a horizontal slide transition: switching to a
/// tab on the right slides it in from the right, and switching to a tab
/// on the left slides it in from the left. The outgoing page plays the
/// reverse of its own entrance, so no zoom/fade residual is visible.
Page<void> _buildTabPage({
  required LocalKey key,
  required int index,
  required Widget child,
}) {
  if (!isMobilePhone) {
    return MaterialPage<void>(key: key, child: child);
  }
  final forward = index >= _currentTabIndex;
  _currentTabIndex = index;
  final begin = forward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOut))
            .animate(animation),
        child: child,
      );
    },
  );
}

// GoRouter configuration
final routerConfig = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: RoutePath.favorites,
  debugLogDiagnostics: true,
  observers: [FlutterSmartDialog.observer],
  errorBuilder: (context, state) => ErrorScreen(message: state.error?.message),
  routes: [
    _applicationShellRoutes,
    GoRoute(
      path: RoutePath.login,
      builder: (context, state) {
        return const LoginScreen();
      },
    ),
    GoRoute(
      path: RoutePath.reader,
      builder: (context, state) {
        final params = state.extra as Map;
        final novelId = params['novelId']!;
        final chapterId = params['chapterId']!;
        return ReaderScreen(
          novelId: novelId,
          chapterId: chapterId,
        );
      },
    ),
    GoRoute(
      path: RoutePath.licenses,
      builder: (context, state) {
        return const LicensesScreen();
      },
    ),
    GoRoute(
      path: RoutePath.license,
      builder: (context, state) {
        final params = state.extra as Map;
        final name = params['name'];
        final license = params['license'];
        return LicenseScreen(
          name: name,
          license: license,
        );
      },
    ),
    GoRoute(
      path: RoutePath.about,
      builder: (context, state) {
        return const AboutScreen();
      },
    ),
    GoRoute(
      path: RoutePath.comments,
      builder: (context, state) {
        final params = state.extra as Map;
        final chapterId = params['chapterId'];
        final novelId = params['novelId'];
        return CommentsScreen(novelId: novelId, chapterId: chapterId);
      },
    ),
    if (isMobilePhone) ...[
      _novelScreenRoute,
      _searchScreenRoute,
    ],
  ],
);

final _applicationShellRoutes = ShellRoute(
  navigatorKey: _shellNavigatorKey,
  builder: (BuildContext context, GoRouterState state, Widget child) {
    return RouterOutletWithNavBar(child: child);
  },
  routes: <RouteBase>[
    GoRoute(
      path: RoutePath.home,
      pageBuilder: (context, state) {
        return _buildTabPage(
          key: const ValueKey('tab-home'),
          index: _tabIndexHome,
          child: SearchScreen(
            initialKeyword: state.uri.queryParameters['keyword'],
          ),
        );
      },
    ),
    GoRoute(
      path: RoutePath.favorites,
      pageBuilder: (context, state) {
        return _buildTabPage(
          key: const ValueKey('tab-favorites'),
          index: _tabIndexFavorites,
          child: const FavoritesScreen(),
        );
      },
      redirect: (context, state) async {
        final cookies = await getCookies();
        if (cookies.isEmpty) {
          return RoutePath.login;
        } else {
          return RoutePath.favorites;
        }
      },
    ),
    GoRoute(
      path: RoutePath.settings,
      pageBuilder: (context, state) {
        return _buildTabPage(
          key: const ValueKey('tab-settings'),
          index: _tabIndexSettings,
          child: const SettingsScreen(),
        );
      },
    ),
    if (isDesktop) ...[
      _novelScreenRoute,
      _searchScreenRoute,
    ],
  ],
);

final _novelScreenRoute = GoRoute(
  path: RoutePath.novel,
  builder: (context, state) {
    final extra = state.extra as Map;
    final novelId = extra['novelId']!;
    final lvLimit = extra['lvLimit'] as int? ?? 0;
    return NovelScreen(novelId: novelId, lvLimit: lvLimit);
  },
);

final _searchScreenRoute = GoRoute(
  path: RoutePath.search,
  builder: (context, state) => const SearchScreen(),
);
