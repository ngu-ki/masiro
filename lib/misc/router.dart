import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:masiro/data/repository/preferences_repository.dart';
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

/// Builds a main-tab page. Tab switches have no transition animation,
/// matching mainstream reading apps (Qidian, Fanqie, WeRead): the new
/// page is shown instantly.
Page<void> _buildTabPage({
  required LocalKey key,
  required Widget child,
}) {
  if (!isMobilePhone) {
    return MaterialPage<void>(key: key, child: child);
  }
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
  );
}

/// Duration of the shared reader enter/exit transition.
const Duration readerTransitionDuration = Duration(milliseconds: 250);

/// A curve that is opaque (1) for the whole forward animation, starting at
/// the very first frame. Used by the reader's opaque cover so the page
/// below is hidden before it can relayout from the status-bar inset change.
class _OpaqueFromStartCurve extends Curve {
  const _OpaqueFromStartCurve();

  @override
  double transformInternal(double t) => t <= 0 ? 0.0 : 1.0;
}

/// Shared transition for the reader: only the reader itself moves (a gentle
/// fade-and-scale), while the underlying route stays completely still.
///
/// The default Material 3 zoom transition slides the underlying page up
/// while the reader is on top and drops it back down on pop, which looked
/// like the detail/shelf page falling when leaving the reader.
///
/// When [instantOpaqueCover] is true, a solid layer painted in the reader's
/// default background color is placed below the fading content: it is fully
/// opaque from the first frame of the forward transition and fades out
/// linearly on pop. The detail page entering the reader that way is not
/// wrapped/frozen and keeps its regular navigation, yet its relayout after
/// the status bar hides is completely hidden behind the cover; by the time
/// the cover fades out on exit the page below has already settled.
Widget readerTransitionsBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child, {
  bool instantOpaqueCover = false,
}) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );
  final content = FadeTransition(
    opacity: curved,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
      child: child,
    ),
  );
  if (!instantOpaqueCover) {
    return content;
  }
  final cover = CurvedAnimation(
    parent: animation,
    curve: const _OpaqueFromStartCurve(),
    reverseCurve: Curves.linear,
  );
  return Stack(
    fit: StackFit.expand,
    children: [
      FadeTransition(
        opacity: cover,
        child: const ColoredBox(
          color: Color(defaultReaderBackgroundColor),
          child: SizedBox.expand(),
        ),
      ),
      content,
    ],
  );
}

/// Builds the reader page for GoRouter routes.
Page<void> _buildReaderPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: readerTransitionDuration,
    reverseTransitionDuration: readerTransitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        readerTransitionsBuilder(
      context,
      animation,
      secondaryAnimation,
      child,
      // Only phones hide the status bar for the reader; desktop keeps the
      // regular fade.
      instantOpaqueCover: isMobilePhone,
    ),
  );
}

/// Builds the reader route for imperative navigators (e.g. the shelf cover
/// tap that pushes while dismissing a loading dialog), keeping the same
/// transition as [_buildReaderPage].
Route<T> buildReaderRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) =>
        builder(context),
    transitionDuration: readerTransitionDuration,
    reverseTransitionDuration: readerTransitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        readerTransitionsBuilder(
      context,
      animation,
      secondaryAnimation,
      child,
      instantOpaqueCover: isMobilePhone,
    ),
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
      pageBuilder: (context, state) {
        final params = state.extra as Map;
        final novelId = params['novelId']!;
        final chapterId = params['chapterId']!;
        return _buildReaderPage(
          key: state.pageKey,
          child: ReaderScreen(
            novelId: novelId,
            chapterId: chapterId,
          ),
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
